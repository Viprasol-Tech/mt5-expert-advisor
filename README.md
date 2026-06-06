<p align="center">
  <img src="docs/assets/logo.png" width="120" alt="Viprasol Tech logo">
</p>

<h1 align="center">MT5 Expert Advisor</h1>

<p align="center">
  <strong>A production-grade MetaTrader 5 (MQL5) Expert Advisor — EMA crossover with trailing stop, break-even, ADX/RSI/session/spread filters, dual money-management modes, a daily trade cap, and an on-chart dashboard.</strong>
</p>

<p align="center">
  <em>Built and maintained by <a href="https://viprasol.com">Viprasol Tech</a> — Fintech Experts. Full-Stack Builders.</em>
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/github/license/Viprasol-Tech/mt5-expert-advisor?style=flat-square&color=blue" alt="License: MIT"></a>
  <img src="https://img.shields.io/badge/platform-MetaTrader%205-orange?style=flat-square" alt="MT5">
  <img src="https://img.shields.io/badge/language-MQL5-blue?style=flat-square" alt="MQL5">
  <img src="https://img.shields.io/badge/version-0.2.0-success?style=flat-square" alt="Version 0.2.0">
  <a href="https://t.me/viprasol_help"><img src="https://img.shields.io/badge/Telegram-support-26A5E4?style=flat-square&logo=telegram&logoColor=white" alt="Telegram"></a>
</p>

---

> ## ⚠️ Disclaimer
> This Expert Advisor is for **educational purposes only** and is **not financial advice**. Trading leveraged instruments carries substantial risk, including the **rapid loss of capital**. Backtest in the **Strategy Tester** and forward-test on a **demo account** before any live use. **Use at your own risk** — Viprasol Tech assumes no responsibility for your trading results.

---

## ✨ Features

- 📈 **EMA crossover signals** — configurable fast/slow periods, MA method, and signal timeframe.
- 💰 **Two money-management modes** — fixed lot *or* risk-percent of equity (sized from the ATR stop distance and tick value), with a hard lot cap.
- 🛡️ **ATR stop-loss & take-profit** — stops and targets scale with volatility.
- 🪜 **ATR trailing stop** — ratchets the stop in your favour, only modifying when the move clears a step threshold.
- 🟰 **Break-even** — locks a small profit once price travels a configurable number of ATRs.
- 🧭 **ADX trend filter** — only trade when trend strength clears a minimum.
- 🌡️ **RSI confirmation** — skip longs when overbought / shorts when oversold.
- 📊 **Spread filter** — block entries when the spread is abnormally wide.
- 🕒 **Session & weekday filter** — restrict trading to a window (midnight-wrap supported) and optionally flatten outside it.
- 🔢 **Max trades per day** — daily cap with automatic server-day reset.
- 🖥️ **On-chart dashboard** — live ATR/ADX/RSI, spread, MM mode, trades-today, session state, open position, and last action.
- 🧱 **Built on `CTrade`** — broker volume constraints (min/max/step) and fill mode respected; a magic-number guard ensures it manages only its own trades.
- 🗂️ **Input groups** — settings organised into clean, labelled sections.

## 🚀 Install & run on MetaTrader 5

1. In MetaTrader 5: **File → Open Data Folder**, then open `MQL5/Experts/`.
2. Copy `src/ViprasolMACrossEA.mq5` into that folder.
3. Open it in **MetaEditor** and press **Compile** (F7) to produce `ViprasolMACrossEA.ex5`.
4. Back in MT5, refresh the Navigator, drag **ViprasolMACrossEA** onto a chart.
5. Tick **Allow Algo Trading**, set your inputs, and click **OK**.
6. Validate first in **View → Strategy Tester** (select the EA, symbol, timeframe, and date range), then forward-test on a **demo** account.

> Compiled `.ex5` binaries are git-ignored — always compile from source in MetaEditor.

## ⚙️ Inputs / parameters

### Signal (EMA crossover)
| Input | Default | Description |
|-------|---------|-------------|
| `FastPeriod` / `SlowPeriod` | 12 / 26 | EMA periods (fast must be < slow) |
| `MAMethod` | `MODE_EMA` | MA smoothing method (SMA/EMA/SMMA/LWMA) |
| `SignalTF` | current | Timeframe used for signals |

### Money management
| Input | Default | Description |
|-------|---------|-------------|
| `MMMode` | `MM_RISK_PCT` | `MM_FIXED_LOT` or `MM_RISK_PCT` |
| `FixedLot` | 0.10 | Lot size in fixed-lot mode |
| `RiskPercent` | 1.0 | Equity % risked per trade in risk mode |
| `MaxLotCap` | 5.0 | Hard cap on computed lots |

### Stops & targets (ATR)
| Input | Default | Description |
|-------|---------|-------------|
| `ATRPeriod` | 14 | ATR period for stops |
| `SL_ATR` / `TP_ATR` | 2.0 / 3.0 | Stop / target as multiples of ATR |

### Trailing stop & break-even
| Input | Default | Description |
|-------|---------|-------------|
| `UseBreakEven` | true | Enable break-even move |
| `BE_TriggerATR` | 1.0 | Profit (ATR) needed to arm break-even |
| `BE_OffsetPts` | 5.0 | Profit locked at break-even (points) |
| `UseTrailing` | true | Enable ATR trailing stop |
| `Trail_ATR` | 2.0 | Trailing distance = `Trail_ATR` × ATR |
| `Trail_StepPts` | 10.0 | Min SL improvement to modify (points) |

### Entry filters
| Input | Default | Description |
|-------|---------|-------------|
| `UseADXFilter` / `ADXPeriod` / `ADXMinLevel` | true / 14 / 20 | Require trend strength |
| `UseRSIFilter` / `RSIPeriod` | true / 14 | RSI confirmation |
| `RSIBuyMax` / `RSISellMin` | 70 / 30 | Block longs above / shorts below |
| `UseSpreadFilter` / `MaxSpreadPts` | true / 30 | Block wide-spread entries |

### Session / time filter
| Input | Default | Description |
|-------|---------|-------------|
| `UseSession` | true | Restrict trading to a window |
| `SessionStartHour` / `SessionEndHour` | 7 / 20 | Window (server time, midnight-wrap ok) |
| `TradeMonday` … `TradeFriday` | true | Per-weekday toggles |
| `CloseOutsideSession` | false | Flatten trades outside the window |

### Trade management & dashboard
| Input | Default | Description |
|-------|---------|-------------|
| `MaxTradesPerDay` | 5 | New trades per day (0 = unlimited) |
| `ExitOnOppositeCross` | true | Close on opposite EMA cross |
| `MagicNumber` | 20250101 | Identifies this EA's trades |
| `MaxSlippage` | 20 | Max slippage (points) |
| `ShowDashboard` | true | Draw on-chart info panel |
| `PanelText` / `PanelFontSize` / `PanelX` / `PanelY` | white / 9 / 12 / 22 | Dashboard styling |

## 🗺️ Roadmap

- [x] EMA crossover core with ATR stops and risk-based sizing
- [x] Trailing stop, break-even, ADX/RSI/session/spread filters
- [x] Fixed-lot vs risk-percent money management
- [x] Max-trades-per-day cap and on-chart dashboard
- [ ] Multi-symbol portfolio mode
- [ ] Equity-curve drawdown circuit breaker
- [ ] Partial take-profit / scale-out
- [ ] Telegram trade notifications

## ❓ FAQ

**Does it repaint?** No. Signals are evaluated only on closed bars (`[1]` and `[2]`); trailing and break-even run intra-bar for responsiveness.

**Which symbols/timeframes?** Any. Defaults suit liquid FX majors on M15–H1, but tune ATR multiples and filters per instrument.

**Risk-percent gives lot 0?** The broker's min lot is larger than your risk budget for that stop distance — lower the stop, raise risk, or switch to fixed-lot mode.

**Why didn't it enter on a cross?** Check the dashboard "Status" line — it reports the exact blocking gate (session, daily cap, spread, ADX, or RSI).

## 🤝 Contributing

Issues and pull requests are welcome. Please keep the EA `CTrade`-based and MQL5-valid, compile cleanly in MetaEditor, and describe the testing you did (Strategy Tester settings, symbol, period). Open an issue first for larger features.

## Contact — Viprasol Tech Private Limited

- Website: [viprasol.com](https://viprasol.com)
- Email: [support@viprasol.com](mailto:support@viprasol.com)
- Telegram: [t.me/viprasol_help](https://t.me/viprasol_help) | WhatsApp: +91 96336 52112
- GitHub: [@Viprasol-Tech](https://github.com/Viprasol-Tech) | [LinkedIn](https://www.linkedin.com/in/viprasol/) | X [@viprasol](https://twitter.com/viprasol)

## License

[MIT](LICENSE) (c) 2025 Viprasol Tech Private Limited
