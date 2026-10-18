# Intake earned-combat cadence regression

The retained earned-route fixture incorrectly required every pistol shot to be at least13 physics ticks apart. NC-02 preserves uninterrupted210ms nominal cadence, which at60Hz requires12/13-tick gaps. The actual accepted ticks673,686,699,711 reproduced the old fixture failure; no production weapon defect was established.

A passive fixture-only oracle now retains nominal phase. It rejects early or cumulative overrate, duplicate/reversed ticks, wrong ammo/count/weapon and unheld discharge. Observed release requires full last-shot recovery; late acceptance discards missed slots without inventing shots. Each callback still requires the physics frame and exact finite ammunition. Player, Main, Enemy, authored maps and the existing fire-intent fixture remain unchanged.

The exact original entry walk, approach, combat and route limits remain600/1200/240 ticks. All23 original actors retain automatic processing and identity. The current native earned prefix completes738 simulated physics ticks, spending five pistol rounds for five hits and one natural worker death, with120 rounds and100HP remaining. Independent correctness and Ponytail reviewers separately compared the oracle against exact-rational arithmetic and found no remaining scoped finding.

Nine assembled source-native scripts pass: cadence oracle, earned combat, entry walk, fire intent, trigger replacement, ammo input, ammo visuals, interaction and pending placement menus. Settings, Controls and difficulty remain active at both placement wait phases and following frames. The original physical capture assertion is unchanged and still needs its app path.

```sh
python3 tools/check_game.py tests/test_intake_cadence.gd tests/test_intake_combat.gd
```

These are headless source-native checks using virtual action input and scripted camera aim. They do not establish human controls, GPU presentation, heard music, a packed app or full campaign balance. The separate west-seal extension is unaccepted: its no-fire candidate encountered a live enemy and its lateral no-fire candidate died. Those failures remain evidence for finite earned-combat work; no inventory grant, invulnerability or relaxed collision was adopted.

Rollback: revert only this fixture change and remove its new pure oracle. Runtime code and assets need no restoration.
