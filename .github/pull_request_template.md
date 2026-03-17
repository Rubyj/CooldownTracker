# Summary of Changes



# Testing

_Describe how to verify this in-game, or note if the change is non-functional (CI, data, docs)._



# Checklist

- [ ] Tested in-game on Midnight (Interface 120001)
- [ ] No new global variables introduced (or `.luacheckrc` updated if needed)
- [ ] No taint-unsafe patterns introduced (no runtime `CreateFrame`, `SetParent`, or `SetScript` on secure frames)
- [ ] `Data.lua` spell entries include both `duration` and `defaultDuration`
- [ ] New dev-only files added to `.pkgmeta` ignore list
- [ ] `## Version:` in `CooldownTracker.toc` bumped if this is a release
