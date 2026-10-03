// Authored synthetic dialogue, never a patch of an existing character or quest.
BEGIN ~B-XBRDL0~

IF ~True()~ THEN BEGIN entry
  SAY ~BGSE laboratory: the ordinary dialogue entry was reached.~
  IF ~~ THEN REPLY ~Accept the laboratory check.~ DO ~SetGlobal("B-XBRREPLY","LOCALS",1)~ EXIT
  IF ~~ THEN REPLY ~Decline the laboratory check.~ DO ~SetGlobal("B-XBRREPLY","LOCALS",2)~ EXIT
END
