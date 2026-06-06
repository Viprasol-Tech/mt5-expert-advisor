# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2025-06-06

### Added
- **ATR trailing stop** (`UseTrailing`, `Trail_ATR`, `Trail_StepPts`) that ratchets the
  stop-loss in the direction of profit, only modifying the order when the improvement
  exceeds a configurable step.
- **Break-even module** (`UseBreakEven`, `BE_TriggerATR`, `BE_OffsetPts`) that locks in a
  small profit once price moves a configurable number of ATRs in your favour.
- **ADX trend filter** (`UseADXFilter`, `ADXPeriod`, `ADXMinLevel`) to require minimum
  trend strength before entering.
- **RSI confirmation filter** (`UseRSIFilter`, `RSIPeriod`, `RSIBuyMax`, `RSISellMin`) to
  avoid buying into overbought / selling into oversold conditions.
- **Spread filter** (`UseSpreadFilter`, `MaxSpreadPts`) to skip entries when the spread is
  abnormally wide.
- **Session / time filter** (`UseSession`, `SessionStartHour`, `SessionEndHour`, per-weekday
  toggles, `CloseOutsideSession`) with support for windows that wrap midnight.
- **Money-management modes** (`MMMode`): fixed lot (`FixedLot`) or risk-percent
  (`RiskPercent`), plus a hard `MaxLotCap`.
- **Max-trades-per-day cap** (`MaxTradesPerDay`) with an automatic server-day reset.
- **On-chart info dashboard** (`ShowDashboard` + colour/size/offset inputs) showing symbol,
  timeframe, MM mode, live ATR/ADX/RSI, spread, trades-today, session state, open position,
  and the EA's last action.
- **Configurable MA method** (`MAMethod`) and **opposite-cross exit toggle**
  (`ExitOnOppositeCross`).
- **Input groups** for a clean, organised settings dialog.
- `CHANGELOG.md` (this file).

### Changed
- Bumped `#property version` to `2.00` and refreshed the EA description.
- Refactored indicator reads into reusable `ReadBuf` / `ReadVal` helpers and centralised
  lot normalisation in `NormalizeVolume`.
- Filling mode now auto-selected via `SetTypeFillingBySymbol`.
- README rewritten to flagship standard (features, install, full inputs reference,
  roadmap, FAQ, contributing).

## [0.1.0] - 2025-01-01

### Added
- Initial release: EMA crossover Expert Advisor with risk-based lot sizing, ATR
  stop-loss / take-profit, once-per-bar logic, opposite-cross exit, and a magic-number
  guard, built on the standard `CTrade` library.

[0.2.0]: https://github.com/Viprasol-Tech/mt5-expert-advisor/releases/tag/v0.2.0
[0.1.0]: https://github.com/Viprasol-Tech/mt5-expert-advisor/releases/tag/v0.1.0
