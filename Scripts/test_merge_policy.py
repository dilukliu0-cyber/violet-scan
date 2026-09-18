#!/usr/bin/env python3
"""Host-side sanity check mirroring ConfidenceGrid merge policy."""

LOCK = 0.85

class Cell:
    def __init__(self, conf, locked=False):
        self.conf = conf
        self.locked = locked

def merge(existing, new_conf, allow_improve_locked=False):
    if existing is None:
        locked = new_conf >= LOCK
        return "addNew", Cell(new_conf, locked)
    if existing.locked and not allow_improve_locked:
        if new_conf > existing.conf + 0.02:
            existing.conf = max(existing.conf, existing.conf * 0.35 + new_conf * 0.65 + 0.02)
            return "improve", existing
        return "skippedLocked", existing
    if new_conf < existing.conf - 0.001:
        return "keepExisting", existing
    existing.conf = max(existing.conf, min(1.0, existing.conf * 0.35 + new_conf * 0.65 + 0.02))
    if existing.conf >= LOCK:
        existing.locked = True
    return "improve", existing

def main():
    c = None
    d, c = merge(c, 0.5)
    assert d == "addNew" and not c.locked
    d, c = merge(c, 0.4)
    assert d == "keepExisting" and abs(c.conf - 0.5) < 1e-6, (d, c.conf)
    d, c = merge(c, 0.95)
    assert d == "improve", d
    #  max(0.5, 0.5*0.35+0.95*0.65+0.02)=max(0.5,0.8125)=0.8125 < 0.85 → still unlocked
    assert abs(c.conf - 0.8125) < 1e-6, c.conf
    d, c = merge(c, 0.99)
    assert d == "improve" and c.locked, (d, c.conf, c.locked)
    d, c = merge(c, 0.5)
    assert d == "skippedLocked"
    print("merge policy OK")

if __name__ == "__main__":
    main()
