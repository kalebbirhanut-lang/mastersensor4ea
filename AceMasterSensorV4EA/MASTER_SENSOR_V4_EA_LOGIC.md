# Ace Master Sensor V4 EA — Complete Trading Logic Reference

## 1. Scope and source of truth

This document describes the original **AceMasterSensorV4EA**, version **1.27**, magic number **640001**, as implemented by:

- `AceMasterSensorV4EA.mq5`
- the `.mqh` modules in `AceMasterSensorV4EA/Include`

It does **not** describe `AceMasterSensorV4UpdatedEA`. The rules below are the deterministic behavior of the code, including defaults, fallbacks, and important limitations. This is documentation, not a claim that the strategy is profitable.

## 2. Executive summary

The EA evaluates only the latest fully closed chart candle. It maintains five signal families:

1. Trend-line continuation, channel, break/retest, and fan signals
2. High-volume displacement (IMB)
3. VWAP/ATR mean reversion
4. CVD-proxy divergence
5. Supply/demand retests

Only the family selected by `InpEntryMode` is traded, unless `ACE_TRADE_ANY_SIGNAL` is selected. The default is `ACE_TRADE_TRENDLINE`. A qualifying setup is sent as a market order after spread, position-count, daily-P/L, daily-entry, and optional loss-streak checks. Position size is normally calculated from the distance between market entry and stop loss.

Default behavior in one line:

> On each closed chart bar, look for an H4 trend-line setup aligned with the H4 50-SMA direction, enter at market with a structural stop, prefer a structural target that satisfies 1.5R, otherwise use 2R, risk 0.5% of balance, partially close 50% halfway to TP, and move the remainder to breakeven.

## 3. Processing lifecycle

### Initialization

On attachment or restart, the EA:

1. Copies all inputs into its internal configuration.
2. Initializes risk and execution modules.
3. Loads at least 200 closed bars; the default request is 1,500 bars.
4. Replays those bars chronologically to rebuild VWAP, CVD, zones, swings, profile, and structure state.
5. Does not emit historical orders during warmup.
6. Fails initialization if fewer than 50 bars are available.

### Live operation

On every tick, the EA first manages partial close and breakeven. It then checks whether chart bar shift 1 has changed. A signal calculation and possible entry occur only once for each newly closed candle. Therefore:

- signals use closed bars, not the forming candle;
- orders are market orders at the first available tick after the signal bar closes;
- actual entry can differ from the signal candle close;
- chart timeframe controls signal frequency;
- HTF filters use their configured timeframes independently.

## 4. Shared market calculations

### ATR and volume

- General ATR: 14 bars by default.
- Displacement ATR: 14 bars by default.
- Volume baseline: 20-bar SMA of the supplied MT5 tick volume.
- High volume: current closed-bar volume is greater than `1.8 × volume SMA`.

Although `InpVolumeIsTick` exists, processing passes `tick_volume` to the engine. The setting is mainly reflected in display text; it does not switch the feed to exchange real volume.

### Displacement candle

A bullish displacement candle requires all of:

- bullish close;
- volume greater than 1.8 times its 20-bar SMA;
- absolute body greater than 1.5 times 14-bar ATR;
- close located in the upper commitment portion: `(close - low) > 75% of range`;
- killzone permission, if killzones are enabled;
- three-bar directional signal cooldown by default.

Bearish logic is mirrored, requiring a bearish close near the candle low.

### Session VWAP and bands

VWAP resets at New York calendar-day rollover and uses typical price:

`typical price = (high + low + close) / 3`

`session VWAP = cumulative(typical price × tick volume) / cumulative tick volume`

Mean-reversion bands are:

- upper band = VWAP + `1.5 × ATR`
- lower band = VWAP - `1.5 × ATR`

### Higher-timeframe bias

The general HTF filter defaults to confirmed H1 data and a 50-period SMA:

- bullish bias: chart close > H1 50-SMA;
- bearish bias: chart close < H1 50-SMA.

If the filter is disabled, or the MA cannot be calculated, both directions are permitted. `InpHtfConfirmed=true` starts the MA calculation from the previous completed HTF candle.

Trend-line models use their own confirmed H4 50-SMA, not the general H1 filter.

### Structure

- Bullish BOS: close above the highest high of the preceding 10 bars.
- Bearish BOS: close below the lowest low of the preceding 10 bars.
- Previous-day/week sweeps require a wick through the stored level and a close back across it.
- Day/session calculations use the EA's New York time helper; risk-day calculations use broker/server midnight.

### Killzones

Killzones are off by default. When enabled, a signal must fall in either configured New York-time window:

- London: 02:00–05:00 NY time
- New York: 07:00–10:00 NY time

The time helper applies US daylight-saving rules.

## 5. Entry-mode selection and routing

`InpEntryMode` selects one of:

- `ACE_TRADE_DISPLACEMENT`
- `ACE_TRADE_REVERSION`
- `ACE_TRADE_SD_RETEST`
- `ACE_TRADE_TRENDLINE` — default
- `ACE_TRADE_ANY_SIGNAL`
- `ACE_TRADE_CVD`

The corresponding `InpTrade...` switch must also be enabled.

In `ANY_SIGNAL` mode, the router returns the first valid signal in this hard-coded order:

1. IMB/displacement
2. Mean reversion
3. Trend line
4. CVD divergence
5. Supply/demand retest

Thus the listed order is practical priority; lower items are not evaluated for execution after an earlier item passes. If both long and short candidates arise inside one family, `ACE_CONFLICT_SKIP` (default) rejects the conflict. `ACE_CONFLICT_HIGHEST` chooses by signal priority, but candidates within the same family have the same priority, so the long candidate wins the tie.

Optional S/D proximity filtering is off by default. If enabled, a long signal bar must overlap a live demand zone and a short bar a live supply zone, allowing a `0.35 × ATR` pad. Trend-line setups bypass this filter by default.

## 6. Entry family A — displacement / IMB

### Long entry

Requires:

- bullish displacement candle as defined above;
- general HTF bullish bias;
- signal/killzone permission;
- not already closed above the upper VWAP+ATR band when `InpSkipImbChase=true`.

### Short entry

Mirrors the long conditions and skips a chase below the lower band.

### Stop and target

- Initial signal stop: signal candle low for long, high for short.
- Because IMB does not own a prebuilt structural stop, the EA adds the configured 5 two-decimal-point buffer beyond it.
- If the resulting stop distance is less than `$1.00` by default, the setup is rejected.
- Default TP: `1.5 × entry-to-stop risk`.

The label “IMB” refers to displacement; the code does not require or track a classic three-candle fair-value-gap fill for entry.

## 7. Entry family B — VWAP mean reversion

### Long entry

With rejection required by default, the closed candle must:

- wick below the lower VWAP−1.5ATR band;
- close back above that band;
- close bullish;
- agree with general HTF bullish bias;
- pass killzone permission if enabled.

If rejection requirement is disabled, merely closing below the lower band qualifies as the location condition.

### Short entry

Mirrored at the upper band: wick above, close back below, bearish candle, and bearish HTF bias.

### Stop and target

- Long SL: signal low − `0.25 × ATR`.
- Short SL: signal high + `0.25 × ATR`.
- Preferred TP: session VWAP.
- If VWAP is on the wrong side of live market entry, it is discarded.
- `InpMrMinRR=0` by default, so no minimum R:R is enforced on the VWAP target.
- If the structural VWAP TP is invalid, fallback TP is 1.5R.

The internally calculated market regime does not block this entry; `RegimeAllows()` always returns true and `mrRegimeOk` is not used by the router.

## 8. Entry family C — CVD-proxy divergence

This is not exchange order-flow CVD. It is accumulated candle volume signed by candle direction.

### Delta modes

- Default `ACE_DELTA_SIGN`: full positive tick volume for bullish candles, full negative volume for bearish candles, zero for doji.
- `ACE_DELTA_BODY`: tick volume multiplied by `(close - open) / candle range`.
- CVD resets at New York day rollover by default.

### Pivot divergence

With lookback 5, a pivot is confirmed only after five bars to the right exist.

- Bullish divergence: newly confirmed price pivot low is lower than the previously stored pivot low, while CVD at the new pivot is higher.
- Bearish divergence: price pivot high is higher, while CVD at that pivot is lower.

### Long/short filters

- Long: bullish raw divergence, HTF bullish bias, signal window allowed.
- Short: bearish raw divergence, HTF bearish bias, signal window allowed.
- With the default VWAP-reached filter, a long is skipped if signal close is already at/above VWAP; a short is skipped if already at/below VWAP.

### Stop and target

- Long SL: confirmed divergence pivot low − 0.25ATR.
- Short SL: confirmed divergence pivot high + 0.25ATR.
- Preferred TP: session VWAP.
- `InpCvdMinRR=0` means no minimum R:R requirement by default.
- Invalid VWAP target falls back to 1.5R.

## 9. Entry family D — supply and demand retest

### Zone creation

Zones are created only following qualifying bullish/bearish displacement. The engine scans backward for up to six base candles. A base candle is an opposite-colored candle or one whose body is no larger than `0.5 × ATR`. Default full-base style uses the highest high and lowest low of the detected base.

Forms are tagged as:

- DBR — drop-base-rally
- RBR — rally-base-rally
- RBD — rally-base-drop
- DBD — drop-base-drop

Overlapping same-side zones are not duplicated. At most eight zones per side are retained; oldest zones are removed first.

### Zone score

A new zone must score at least 6. Approximate components are:

- +2 aligned general HTF bias
- +2 freshness at creation
- +2 explosive departure
- −2 if departure is not explosive
- +2 break of 10-bar structure
- +2 liquidity sweep into the base, with +1 extra for swept DBR/RBD forms
- +1 departure creates a three-candle FVG
- +1 high volume
- +1 supportive CVD state
- +1 demand in discount or supply in premium versus the 40-bar dealing-range midpoint
- −2 if an opposing zone is within 1 ATR

Grade labels are A for score ≥8, B for ≥6, otherwise C. Each touch reduces adjusted score by 2; a second touch reduces it by another 2.

### Retest entry

A retest candle must overlap the zone and the pre-touch adjusted score must still meet the minimum. With defaults, it then needs:

- a zone/tap sweep and close back acceptably relative to the zone;
- market-structure shift/BOS, a close beyond the zone, or a short lookback structure break;
- same-direction raw displacement or a same-direction rejection candle;
- general HTF alignment;
- premium/discount agreement;
- killzone permission if enabled.

The zone is marked signaled so it cannot repeatedly fire while price stays inside it. Leaving the zone re-arms it. A displacement through the wrong edge invalidates it; acceptance through it can also invalidate it after excessive tests.

### Stop and target

- Demand long: below the sweep low (or zone bottom) with `0.5 × ATR` padding.
- Supply short: above the sweep high (or zone top) with the same padding.
- Preferred target: nearest opposing zone in the trade direction.
- If no valid opposing-zone target exists, TP falls back to 1.5R.
- No global minimum R:R is enforced for this original build.

## 10. Entry family E — trend-line system (default)

### Trend-line construction

- Pivot swings use 3 bars left and 3 right.
- Consecutive stored swings must be at least 5 bars and 0.5ATR apart.
- Up to 80 swings/history elements are considered.
- Primary support joins the latest two accepted pivot lows.
- Primary resistance joins the latest two accepted pivot highs.
- Parallel channel boundaries are projected from the opposite extreme.
- Lines expire when their last touch is more than 80 bars old.
- Touch tolerance is `0.15 × ATR`.
- Stop padding is `0.25 × ATR`.
- Direction is determined by close versus the confirmed H4 50-SMA.

`InpTlModel=ANY` evaluates continuation, channel, break/retest, and fan models. If more than one sets the same direction on a bar, the later evaluation can overwrite the tag/levels.

### TL continuation

Looks for price at primary support/resistance, liquidity sweep or reclaim, bullish/bearish rejection, H4 direction alignment, and structural confirmation. The default MSS and displacement switches make both structure and raw displacement important gates. Price must close back on the valid side of the line.

### TL channel

Uses the projected channel extreme rather than the primary line. It requires touch, liquidity event, HTF direction, rejection, BOS/displacement confirmation, and a stronger internal confluence threshold than continuation.

### TL break and retest

- Bearish: support closes broken with bearish BOS and bearish raw displacement, then a later candle retests from below and retains bearish confirmation.
- Bullish: resistance closes broken with bullish BOS and bullish raw displacement, then retests from above.
- A false-break/trap close back through the line clears broken state.

### TL fan

Constructs several lines from a swing anchor. A close crossing the configured final fan line generates the opposite-direction exhaustion signal. Unlike the other TL models, fan evaluation does not explicitly apply the H4 direction, MSS, displacement, killzone, or rejection gates in `EvalFan()`.

### Trend-line stop and target

Long structural stop is the lowest of signal-bar low, previous-day low, and latest stored pivot low, minus 0.25ATR. Short logic is mirrored using highs.

Target priority for longs:

1. upper channel boundary above price
2. volume-profile VAH above price
3. volume-profile POC above price
4. previous-day high above price
5. fallback 2R

Short targets mirror this using lower channel, VAL, POC, and previous-day low.

A structural TL target is retained only if it is correctly placed and its R:R is at least `InpTlMinRR=1.5`. Otherwise the EA substitutes `InpTlTpR=2.0R`.

## 11. Market entry and order validation

All entries are immediate market orders:

- buy entry reference = current ask;
- sell entry reference = current bid.

Before sending, the EA checks:

- a nonzero valid structural stop exists;
- stop is on the correct side of current entry;
- risk distance is at least one tick;
- IMB-only minimum `$1.00` stop width;
- normalized SL and TP satisfy broker minimum stop distance;
- risk manager permits a new position.

The EA uses the broker’s preferred fill policy first, then tries IOC, FOK, and RETURN alternatives. Slippage default is 50 points expressed for two-decimal gold (`$0.50`), scaled to symbol digits. Order comments are truncated to 31 characters.

## 12. Target-selection rules

Default mode is `ACE_TP_STRUCTURAL`:

- use the signal-specific structural TP when valid;
- enforce family-specific minimum R:R where configured;
- otherwise substitute the applicable R-multiple target.

Global `ACE_TP_VWAP` mode can override the selected target with session VWAP if VWAP lies in the profitable direction and satisfies `InpVwapMinRR`. With the default `InpVwapMinRR=0`, any correctly placed VWAP target is accepted, even below 1R.

There is no trailing stop and no time-based exit.

## 13. Position sizing

### Risk-percent mode (default)

`risk money = account balance × 0.5%`

`loss per lot = (absolute entry-to-SL distance / tick size) × tick value`

`raw lots = risk money / loss per lot`

Volume is floored to broker volume step, then clamped to broker and user min/max limits.

Important consequences:

- sizing uses **balance**, not equity;
- commission, spread, and slippage are not included in the risk calculation;
- if computed volume is below broker/user minimum, it is rounded **up** to minimum lot, which can exceed intended 0.5% risk;
- if tick metadata or stop distance is invalid, the code falls back to the fixed-lot value rather than rejecting;
- user `InpMinLot` and `InpMaxLot` are inactive at zero and otherwise further clamp broker limits.

### Fixed-lot mode

When `InpUseFixedLot=true`, the configured 0.01 lot is normalized and clamped to permitted limits. Stop distance does not change the volume.

## 14. Risk gates and trading halts

### Spread

Default maximum is 80 two-decimal gold points (`$0.80`), scaled for symbol digits.

### Position count

Default maximum is one open position matching both symbol and magic number. Other symbols, other magic numbers, and manual positions are not counted.

### Daily loss/profit halt

- Default daily loss threshold: 3%.
- Daily profit halt is disabled at 0%.
- Baseline is account balance at broker/server midnight.
- Trigger compares current **account equity** with that starting balance.
- Once triggered, new entries are blocked for the rest of that server day.
- Existing positions are **not** closed by the halt.
- The calculation is account-wide: P/L from other EAs/manual trades can trigger it.
- State is not persisted across terminal/EA restart; restart establishes a fresh in-memory baseline.

### Trades per day

Disabled by default (`0`). If enabled, it counts `DEAL_ENTRY_IN` deals for the current symbol and magic since server midnight. Partial/increasing entry deals can affect the count.

### Consecutive-loss cooldown

Both maximum consecutive losses and cooldown hours are disabled by default (`0`). If enabled, the manager scans matching symbol/magic exit deals backward and sums each deal's profit, swap, and commission. On reaching the limit it blocks entry and, if hours are positive, sets an in-memory cooldown-until time.

Because partial exits are individual exit deals, they can influence the streak independently of the final position result.

## 15. Open-position management and exits

The EA manages only positions matching its chart symbol and magic number.

### Hard exits

- Broker-side stop loss
- Broker-side take profit
- Manual closure or external intervention

There is no opposite-signal exit, time exit, end-of-day flattening, drawdown flattening, or trailing stop.

### Partial close

Defaults:

- trigger after price travels 50% of the distance from entry to TP;
- close 50% of current volume;
- floor close volume to broker step;
- skip permanently for that in-memory ticket if either closed or remaining volume would be below broker minimum.

### Breakeven

At the same TP-progress threshold, the EA attempts to move SL to entry. Default offset is zero. It respects broker minimum stop distance, which can force the requested SL away from exact entry. Breakeven is attempted even if a partial close is impossible or fails.

Partial/BE completion arrays are memory-only. Reattaching or restarting the EA clears them, so an already reduced live position may be processed again if it remains beyond the trigger.

## 16. Defaults quick reference

| Area | Default |
|---|---:|
| Entry mode | Trend line |
| Magic | 640001 |
| Risk | 0.5% of balance |
| Fixed lot | Off; 0.01 fallback/configured size |
| Maximum positions | 1 |
| Daily loss halt | 3% |
| Daily profit halt | Off |
| Max trades/day | Off |
| Loss-streak cooldown | Off |
| Maximum spread | $0.80 on two-decimal gold convention |
| Generic target | 1.5R |
| Trend-line fallback target | 2R |
| Trend-line minimum structural target | 1.5R |
| IMB minimum stop width | $1.00 |
| Partial | 50% volume at 50% TP progress |
| Breakeven | At partial threshold, zero offset |
| Killzones | Off |
| General HTF filter | Confirmed H1 50-SMA |
| Trend-line HTF filter | Confirmed H4 50-SMA |
| S/D proximity requirement | Off |

## 17. Operational cautions

1. The EA was designed around gold-style point conventions, but broker contract size, tick value, suffixes, and stop levels must be verified.
2. Minimum-lot clamping can create risk greater than the configured percentage.
3. The daily halt blocks new entries only; it is not a guaranteed daily drawdown cap.
4. Risk-day and signal-session boundaries use different clocks.
5. CVD is a tick-volume candle proxy, not true bid/ask delta.
6. Structural targets may be replaced with fixed-R targets when invalid or below configured family-specific R:R.
7. Several inputs/fields are diagnostic or unused in actual admission logic, including regime gating.
8. Backtest using real ticks, variable spreads, commission, and the exact broker symbol. Then forward-test on demo before considering live use.

## 18. Practical setup checklist

Before enabling live orders:

1. Confirm chart symbol and timeframe.
2. Select exactly the intended `InpEntryMode`.
3. Confirm the related `InpTrade...` switch is true.
4. Validate tick size/value and lot sizing in Strategy Tester logs.
5. Decide whether minimum-lot risk overruns are acceptable.
6. Decide whether 3% account-wide daily halt behavior matches the account.
7. Enable max trades/day and loss cooldown explicitly if desired; defaults do not limit them.
8. Verify server time versus New York killzones/session resets.
9. Test partial close support for the account’s netting/hedging mode and broker.
10. Use `InpTradeEnabled=false` first if only observing dashboard signals.

