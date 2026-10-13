"""A4d handcrafted counted-buffer cases; all inputs are synthetic owned bytes."""
from __future__ import annotations

import pytest

from test_process_command_buffer import BASE, descriptor, invoke


MAX_U64 = (1 << 64) - 1
REFUSAL_FIELDS = {"code", "type", "hasInner", "operation", "kind", "nativeError"}


def decoded(result, value: str) -> None:
    assert result == {"code": "decoded", "value": value, "inputUnchanged": True}


def refused(result, suffix: str) -> None:
    assert set(result) == REFUSAL_FIELDS, result
    assert result["code"] == "BGSE_E_PROCESS_COMMAND_" + suffix, result
    assert result["type"] == "Bgse.Lab.MeasurementRefusal", result
    assert result["hasInner"] is False, result
    assert isinstance(result["operation"], str) and result["operation"], result
    assert isinstance(result["kind"], str) and result["kind"], result
    if suffix != "STATUS":
        assert result["nativeError"] is None, result
        assert (result["operation"], result["kind"]) == ("guard", "guard"), result


@pytest.mark.parametrize("frame,base,prepare", [
    (None, BASE, ""),
    (b"", BASE, ""),
    (b"\x00" * 15, BASE, ""),
    (descriptor(0, 0, 0), 0, ""),
    (descriptor(0, 0, 0), MAX_U64 - 15, ""),
    (descriptor(0, 0, 0), BASE, "$bytes = [byte[]]::new(65553); $returned = [uint32]16"),
])
def test_invalid_input_refuses_before_status_or_descriptor(frame, base, prepare):
    # A nonzero status and malformed return count cannot mask invalid input.
    refused(invoke(frame, base=base, returned=0, status=-1, prepare=prepare), "INPUT")


def test_exclusive_allocation_end_at_uint64_max_is_representable():
    decoded(invoke(descriptor(0, 0, 0), base=MAX_U64 - 16), "")


def test_nonnull_full_width_pointer_can_address_owned_payload_without_wrapping():
    frame = descriptor(2, 2, MAX_U64 - 2, b"a\x00")
    decoded(invoke(frame, base=MAX_U64 - 18), "a")


@pytest.mark.parametrize("status", [1, 0x40000000, -1, -1_073_741_823])
def test_nonzero_signed_status_precedes_returned_count_and_bad_descriptor(status: int):
    # Length 1 > MaximumLength 0 and returned=0 would otherwise be DATA.
    result = invoke(descriptor(1, 0, 0), returned=0, status=status)
    refused(result, "STATUS")
    assert (result["operation"], result["kind"], result["nativeError"]) == (
        "decode", "ntstatus", status,
    )


@pytest.mark.parametrize("status", [0x40000000, -1_073_741_823])
def test_nonzero_status_refuses_even_a_valid_counted_string(status: int):
    result = invoke(descriptor(2, 2, BASE + 16, b"a\x00"), status=status)
    refused(result, "STATUS")
    assert (result["operation"], result["kind"], result["nativeError"]) == (
        "decode", "ntstatus", status,
    )


@pytest.mark.parametrize("returned", [0, 1, 15, 17, 4_294_967_295])
def test_returned_extent_must_cover_header_and_fit_supplied_array(returned: int):
    refused(invoke(descriptor(0, 0, 0), returned=returned), "DATA")


@pytest.mark.parametrize("length,maximum,pointer,payload", [
    (1, 2, BASE + 16, b"a\x00"),       # Odd content length.
    (2, 3, BASE + 16, b"a\x00\x00"), # Odd maximum length.
    (4, 2, BASE + 16, b"a\x00b\x00"), # Content exceeds maximum.
    (2, 2, 0, b"a\x00"),               # Null pointer with content.
    (0, 2, 0, b"\x00\x00"),           # Null pointer with capacity.
])
def test_invalid_descriptor_lengths_and_null_pointer_refuse(
    length: int, maximum: int, pointer: int, payload: bytes,
):
    refused(invoke(descriptor(length, maximum, pointer, payload)), "DATA")


@pytest.mark.parametrize("pointer", [
    BASE - 1,             # Underflow on subtracting original base.
    BASE,                 # Points into the header.
    BASE + 14,            # Last two header bytes.
    BASE + 19,            # Beyond the returned extent of a 16-byte frame.
    MAX_U64,              # Far outside the supplied allocation.
])
def test_nonnull_pointer_must_address_the_returned_payload(pointer: int):
    refused(invoke(descriptor(0, 0, pointer)), "DATA")


def test_content_fit_does_not_excuse_maximum_span_outside_returned_extent():
    frame = descriptor(2, 4, BASE + 16, b"a\x00")
    refused(invoke(frame), "DATA")


def test_pointer_inside_allocation_but_beyond_returned_extent_refuses():
    frame = descriptor(0, 0, BASE + 18, b"a\x00")
    refused(invoke(frame, returned=16), "DATA")


def test_maximum_span_inside_allocation_but_beyond_returned_extent_refuses():
    frame = descriptor(2, 4, BASE + 16, b"a\x00\x00\xd8")
    refused(invoke(frame, returned=18), "DATA")


def test_nonempty_content_cannot_start_at_one_past_returned_end():
    frame = descriptor(2, 2, BASE + 18, b"a\x00")
    refused(invoke(frame), "DATA")


@pytest.mark.parametrize("pointer,payload", [
    (0, b""),
    (BASE + 16, b""),
    (BASE + 20, b"\xff\xff\xff\xff"),
])
def test_zero_length_zero_maximum_empty_and_one_past_forms(
    pointer: int, payload: bytes,
):
    decoded(invoke(descriptor(0, 0, pointer, payload)), "")


def test_nonnull_empty_text_may_have_valid_reserved_capacity():
    decoded(invoke(descriptor(0, 2, BASE + 16, b"\x00\xd8")), "")


def test_refusal_does_not_export_synthetic_command_payload():
    canary = "PRIVATE_COMMAND_BUFFER_CANARY"
    payload = canary.encode("utf-16-le")
    result = invoke(descriptor(len(payload), len(payload), BASE - 1, payload))
    refused(result, "DATA")
    assert canary not in str(result)


@pytest.mark.parametrize("payload", [
    b"\x00\xd8",         # Unpaired high surrogate.
    b"\x00\xdc",         # Unpaired low surrogate.
    b"\x00\xdc\x00\xd8", # Reversed surrogate pair.
    b"a\x00\x00\x00", # Embedded NUL character.
])
def test_strict_utf16_and_embedded_nul_refuse(payload: bytes):
    refused(invoke(descriptor(len(payload), len(payload), BASE + 16, payload)), "DATA")


def test_padding_unused_capacity_and_tail_are_ignored_without_terminator():
    # The counted text begins at offset 20. Both the unused maximum span and
    # subsequent tail contain malformed UTF-16, which is outside Length.
    payload = b"\xaa" * 4 + "OK".encode("utf-16-le") + b"\x00\xd8" + b"\x00\xd8"
    frame = descriptor(4, 6, BASE + 20, payload, padding=b"\xff" * 4)
    decoded(invoke(frame), "OK")


def test_maximum_counted_string_uses_owned_large_fixture_not_environment_data():
    # The 65,552-byte allocation is created in PowerShell. Returned extent
    # ends at 65,550; the last two allocation bytes are unused.
    prepare = r"""
    $bytes = [byte[]]::new(65552)
    [BitConverter]::GetBytes([uint16]65534).CopyTo($bytes,0)
    [BitConverter]::GetBytes([uint16]65534).CopyTo($bytes,2)
    [BitConverter]::GetBytes([uint64]($base + 16)).CopyTo($bytes,8)
    for ($i=16; $i -lt 65550; $i+=2) { $bytes[$i] = [byte]0x61 }
    $returned = [uint32]65550
    """
    decoded(invoke(descriptor(0, 0, 0), prepare=prepare), "a" * 32_767)
