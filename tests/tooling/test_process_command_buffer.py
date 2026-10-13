"""A4d supplied bytes only: never query a process or dereference an address."""
from __future__ import annotations

import base64
import json
import os
import struct
import subprocess

import pytest

from test_environment_contract import POWERSHELL_PATH, REPOSITORY_ROOT

BASE = 0x100000


def descriptor(length: int, maximum: int, pointer: int, payload: bytes = b"",
               padding: bytes = b"\x00" * 4) -> bytes:
    return struct.pack("<HH", length, maximum) + padding + struct.pack("<Q", pointer) + payload


def text_frame(text: str) -> bytes:
    payload = text.encode("utf-16-le")
    return descriptor(len(payload), len(payload), BASE + 16, payload)


def invoke(frame: bytes | None, *, base: int = BASE, returned: int | None = None,
           status: int = 0, prepare: str = ""):
    # Large fixtures are built inside the harness using authored prepare code,
    # never a Windows environment variable exceeding its per-value limit.
    assert frame is None or len(frame) <= 16000
    environment = os.environ.copy()
    environment["BGSE_COMMAND_LIBRARY"] = str(REPOSITORY_ROOT / "scripts" / "lib")
    environment["BGSE_COMMAND_FRAME"] = base64.b64encode(frame or b"").decode("ascii")
    environment["BGSE_COMMAND_NULL"] = "1" if frame is None else "0"
    environment["BGSE_COMMAND_BASE"] = str(base)
    environment["BGSE_COMMAND_RETURNED"] = str(len(frame or b"") if returned is None else returned)
    environment["BGSE_COMMAND_STATUS"] = str(status)
    command = r"""
$ErrorActionPreference = 'Stop'
try {
    Add-Type -Path @((Join-Path $env:BGSE_COMMAND_LIBRARY 'SourceMeasurement.cs'),
                    (Join-Path $env:BGSE_COMMAND_LIBRARY 'ProcessCommandBuffer.cs'))
    [byte[]]$bytes = $null
    if ($env:BGSE_COMMAND_NULL -ne '1') { $bytes = [Convert]::FromBase64String($env:BGSE_COMMAND_FRAME) }
    $base = [uint64]::Parse($env:BGSE_COMMAND_BASE)
    $returned = [uint32]::Parse($env:BGSE_COMMAND_RETURNED)
    $status = [int32]::Parse($env:BGSE_COMMAND_STATUS)
    PREPARE
    $before = if ($null -eq $bytes) { $null } else { [Convert]::ToBase64String($bytes) }
    $value = [Bgse.Lab.ProcessCommandBuffer]::Decode($bytes,$base,$returned,$status)
    $unchanged = $before -ceq [Convert]::ToBase64String($bytes)
    if ($bytes.Length -gt 0) { [Array]::Clear($bytes,0,$bytes.Length) }
    # Keep the actual decoded value, but escape non-ASCII JSON before the
    # process writer can replace it under a hidden/legacy output encoding.
    @{ code='decoded'; value=$value; inputUnchanged=$unchanged } | ConvertTo-Json -Compress -Depth 4 -EscapeHandling EscapeNonAscii
} catch {
    $failure = $_.Exception
    while ($null -ne $failure.InnerException) { $failure = $failure.InnerException }
    @{ code=$failure.Message; type=$failure.GetType().FullName;
       hasInner=($null -ne $failure.InnerException);
       operation=$failure.Diagnostic.operation; kind=$failure.Diagnostic.failureKind;
       nativeError=$failure.Diagnostic.nativeError } | ConvertTo-Json -Compress -Depth 4 -EscapeHandling EscapeNonAscii
}
""".replace("PREPARE", prepare)
    result = subprocess.run([POWERSHELL_PATH, "-NoProfile", "-Command", command],
                            cwd=REPOSITORY_ROOT, env=environment, capture_output=True,
                            timeout=30, check=False,
                            creationflags=subprocess.CREATE_NO_WINDOW)
    assert result.returncode == 0, result.stderr
    assert not result.stderr, result.stderr
    # A UTF-8 StreamWriter may add one transport preamble. A BOM in the decoded
    # string remains inside the JSON value and must survive the exact assertion.
    output = result.stdout.removeprefix(b"\xef\xbb\xbf")
    assert output.isascii(), output
    return json.loads(output.decode("ascii"))


def test_counted_text_preserves_quotes_spaces_bom_and_unicode_without_terminator():
    value = '\ufeff"synthetic tool"  --label "\U0001f600"  '
    result = invoke(text_frame(value))
    assert result == {"code": "decoded", "value": value, "inputUnchanged": True}


@pytest.mark.parametrize("codepage", [20127, 437, 949, 65001])
def test_exact_decoded_text_survives_hidden_process_output_encodings(codepage):
    value = '\ufeff"naïve-한글-\U0001f600"  --literal "\\u1234"\t\r\n'
    # Change only this fresh harness's managed output writer, never the shared
    # console code page, parent environment or another process. ASCII explicitly
    # reproduces the observed hidden full-run loss; UTF-8 checks the other end.
    prepare = f"""
    $writer=[IO.StreamWriter]::new([Console]::OpenStandardOutput(), [Text.Encoding]::GetEncoding({codepage}))
    $writer.AutoFlush=$true
    [Console]::SetOut($writer)
    """
    result = invoke(text_frame(value), prepare=prepare)
    assert result == {"code": "decoded", "value": value, "inputUnchanged": True}
