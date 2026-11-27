# MHGU Charm Sniping Guide

[English](charm-sniping-en.md) | [Português (Brasil)](charm-sniping-pt-BR.md) | [Español](charm-sniping-es.md)

This guide explains how to obtain specific charms (including God Charms) in Monster Hunter Generations Ultimate using **MHGU Charms RNG** and the item-combination method. The app calculates RNG positions and timings; it does not modify the game or save file. You do not need a modded Switch or Python.

## 1. Download the app

Download the appropriate ZIP from the [latest release](https://github.com/jasmithc/mhgu-rng-app/releases/latest).

- **Windows:** extract the entire archive, keep the DLLs alongside the executable and open MHGU Charms RNG.exe.
- **macOS:** extract the archive and move the app into Applications.
- For system security warnings, requirements and optional iPhone/iPad installation instructions, see the [README](../../README.md).

The instructions below use the English interface labels. Keep **Language** set to English.

## 2. Prepare the game

- Remove accompanying Palicos and set your Room Service attendant to the Moga Village receptionist.
- Carry Combo Book 1, 99 Huskberries and 99 Needleberries. Ensure the Normal S Lv2 recipe has a 100% success rate and that you have no Normal S Lv2 in your pouch.
- For Enduring Charms, unlock Juju Melding and bring **three King Talismans (dark blue, rarity 6)** that you do not mind using for melding. This is my recommended combination and gives Rank 4. Queen and Dragon Talismans also qualify, but I recommend using three King Talismans.
- Make sure the Switch album has room for a 30-second video.
- Save in Kokoto Village with everything prepared. This is the save you will reload between unsuccessful attempts.

**Do not run from the moment you load your character until you confirm the meld.** Running can advance the RNG in unexpected ways. Always walk, including on your way to your room. After confirming the meld, you can run normally.

## 3. Find a target charm

Open **Charm Search**. Use the **God charms** presets or choose the charm kind, skills, points and slots manually. For example, choose Enduring, Tenderizer +6, Expert +10, three slots and **Source: Melding**.

- **Exact:** match the selected requirements exactly.
- **At least:** match or exceed the selected requirements.

Set **Start frame** to 0 and choose a search count under **Frames to search** (increase it if you find no results). Enable **Set Continue Cycles target to the frame found** and press **Run**.

Record the frame of the desired result. The first result automatically fills **Target frame** in the timer panel; change it manually if you choose another result. Use an attainable charm relatively early in the sequence for practice. For other charm types, check the appropriate meld and aim points.

## 4. Calculate the Continue Cycles

Each press of Continue advances the RNG by approximately 702 additional positions. The RNG also normally advances at 30 frames per second.

The **Continue Cycles** calculator estimates the number of cycles needed while leaving about two minutes to spare. The **Continue Counter** target updates automatically.

Set **Pace** to 60 BPM initially. You may try 75 or 90 BPM once comfortable. Above 90 BPM, loading may not finish before your B press and the following A press could accidentally load your character.

### Poogie safety buffer

The original purpose of **Poogie?** is to subtract five Continue Cycles to allow time to remove Poogie. In my successful testing, I did not need to remove Poogie, but I enabled this option anyway as a safety buffer.

I recommend ticking it even if you leave Poogie in the room. Those five fewer cycles provide additional margin if you accidentally press Continue too many times or take longer than expected. Arriving early and waiting a little longer is preferable to overshooting.

## 5. Perform the Continue Cycles

1. Completely close and relaunch MHGU.
2. At the title menu, start **Continue Counter**.
3. At each beat, press A on Continue, then press B when the character selection screen appears to return to the title menu.
4. On the final count (a longer, higher beep), select Continue and load your character instead of returning to the title menu.

Keep the pace consistent. For an early target, you may not need any cycles; load your character and proceed directly.

## 6. Identify your current RNG position

### Prepare the combination

1. Walk to your room without running. Removing Poogie is optional, based on the testing described above.
2. Open the **Combo List** and locate Normal S Lv2 (Huskberry + Needleberry).
3. Press A **once** to select the recipe and open the small Combine menu. **Do not start the Stopwatch yet.**

### Combine and time

1. With the small Combine menu already open, prepare the app's **Stopwatch** (reset it if necessary).
2. Press and hold A again to actually begin combining. **Start the Stopwatch at exactly the same moment you begin holding A.**
3. Keep holding A until the ammunition count reaches 99 and no more can be combined.

The first press opens the menu; the second, held press starts the combinations and the Stopwatch.

### Record and suspend

1. Once the count reaches 99, release A.
2. **Press and hold the Switch Capture button** to save a video of the preceding 30 seconds.
3. Leave the Stopwatch running while the clip is saved.
4. **Press HOME on the Switch and stop the Stopwatch at exactly the same moment.**

Do not stop the Stopwatch at 99 or when pressing Capture. The RNG still advances until the game is suspended. Keep MHGU suspended in the HOME menu while performing the following steps; do not close or resume the game.

## 7. Use Item Combo Search

Watch the clip in the Switch album. Pause and scrub through it to record every distinct ammunition count, from 0 to 99, in order.

Example (illustrative beginning only): `0 2 4 7 10 13 16 18 22 25 28 30 32 35 39 42 45 … 99`. Do not enter the ellipsis; use your own complete sequence, with spaces between counts.

1. Open **Item Combo Search**.
2. Paste the recorded counts into the combination field.
3. Set the search start and count to cover your expected position before the target (or start at 0 and search through the target if necessary).
4. Press **Run** and note the reported frame.

Use the reported frame directly: the tool already accounts for RNG advances caused by combining items. Do not add those advances again.

If there are no matches, invalid differences or a low-confidence warning, recheck every count and the search range. The app also detects minor timing stutters, so do not delete values just to force a match. A narrower range helps distinguish random matches.

## 8. Calculate the wait time

Open **Frame → Wait Time**. Enter the target frame and enable **Subtract a baseline frame**, entering the frame returned by Item Combo Search as the baseline. Alternatively, enter the difference directly without the baseline option.

Example:

| Value | Frame |
| --- | ---: |
| Target | 296260 |
| Item Combo Search result | 292660 |
| Difference | 3600 |

At 30 frames per second, 3600 frames equal two minutes. Press **Run** to populate the **Final Countdown** wait time.

The countdown automatically uses:

**Remaining time = Wait Time − Stopwatch + Correction**

Do not subtract the Stopwatch yourself. Initially use a correction of 0. If the remaining time is not positive, or there is insufficient time to prepare the meld, restart the attempt with fewer Continue Cycles.

## 9. Perform the meld

1. While the game is still suspended, check the **Final Countdown** values.
2. **Resume MHGU and press Start Countdown at exactly the same moment.**
3. Walk to Room Service. Do not run.
4. Select Juju Melding for Enduring Charms and select the three King Talismans (dark blue).
5. Proceed to the final confirmation, but do not submit the charms yet.
6. The app beeps every second during the last ten seconds and plays a long beep at zero. **Confirm the meld on that final beep.**

Once the meld has been submitted, its result is determined and it is safe to run again.

## 10. Check the results without saving

Complete a quest to make the results available.

**Do not save after completing the quest. Choose No if prompted to save.** Collect the melding results and inspect your charms first.

- If you obtained the desired charm, save the game.
- If not, record the charms received (skills, points and slots; a screenshot is useful), then completely close the game without saving. Reload your original prepared save for another attempt.

Not saving an unsuccessful attempt preserves your combination materials and the charms used for melding. Only save when you are happy with the result.

## 11. Adjust the timing

Use **Around a Frame** with the target frame, the correct charm kind and **Source: Melding** to inspect nearby charms. **Halcyon / Juju Meld** lets you inspect the full predicted result for a particular submission frame; use Juju and Rank 4 for the recommended three King Talismans.

Compare the predicted charms with your actual results. If you identify that you confirmed 15 frames too late, enter **−15 frames** (or −0.5 seconds) in **Correction** for the next attempt. If you were early, use a positive correction. A positive correction waits longer; a negative one waits less.

If you cannot identify the result near the target, recheck the item-combination sequence, walking instead of running, timer synchronisation, meld rank and search range.

## Quick checklist

- [ ] Prepare and save in Kokoto; select the target charm.
- [ ] Enable the Poogie safety buffer and calculate Continue Cycles.
- [ ] Restart MHGU and perform the cycles.
- [ ] Load your character and walk to your room.
- [ ] Open the small Combine menu for Normal S Lv2.
- [ ] Hold A and start Stopwatch simultaneously; combine to 99.
- [ ] Hold Capture to save the 30-second clip.
- [ ] Press HOME and stop Stopwatch simultaneously.
- [ ] Enter the complete sequence into Item Combo Search.
- [ ] Calculate Frame → Wait Time and check Final Countdown.
- [ ] Resume the game and start the countdown simultaneously.
- [ ] Walk to Room Service and confirm the meld on the final beep.
- [ ] Complete a quest without saving; inspect the results.
- [ ] Save only if satisfied; otherwise restart without saving and adjust Correction.

## Further reading

- [Original item-combination method (English)](https://github.com/jasmithc/mhgu-rng/blob/main/docs/combo_snipe.md)
- [Melding ranks and mechanics](https://github.com/jasmithc/mhgu-rng/blob/main/docs/melding.md)
- [Original RNG research](https://github.com/apmnnn/mhxx-rng)
- [Charm skill tables](https://mhgu.kiranico.com/charms)
- [Video introduction by Clobincole](https://www.youtube.com/watch?v=6aXJoX2hKOI)
