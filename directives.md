# Directives for Unattended Execution

Check this file at the start of every turn. Active directives are at the top, completed ones move to the bottom.

## Active Directives

<!-- Add new directives here with date and priority -->

- [x] **2026-06-08 — Beating Buy & Hold: Research the Minority Who Beat Index Investing (PRIORITY #3, DEEP RESEARCH)** — PHASES A-F COMPLETE
   **Background:** Previous ML (Phases 1-5) and Dual Momentum (Phases 6-7) strategies both underperformed SPY buy-and-hold. The SPIVA data shows 85-95% of active fund managers fail to beat their benchmarks long-term. This research pivots to studying the 5-15% who DO succeed.
   **Phase A-E: COMPLETE (2026-06-08)** — Comprehensive research at `future_project_ideas/stock_market_prediction/BEATING_BUY_HOLD.md`. Key findings: SPIVA 79% underperform in 2025; HFT NOT feasible for retail (latency 1000-5000x too slow, $10K-50K/mo colocation); winners share 6 common patterns (concentration, asymmetric risk/reward, capital preservation, liquidity focus, time horizon, behavioral edge).
   **Qwen 3.7 Max Strategic Response (2026-06-08):** Quality + Momentum + Small-Cap Value via sequential filter. Static weights, quarterly rebalancing (mid-month). No ML timing (52-60% accuracy useless for timing). ETF picks: VFMF, AVUV, QMOM. Realistic edge: 1.5-2.5% annualized over SPY, 15+ year horizon. Will underperform during tech bull runs (3-5 year stretches).
   **Phase F — Build Sequential Filter Prototype: COMPLETE (2026-06-08)** — Built sequential_filter/ module: fundamentals.py (yfinance batch fetcher), quality_screener.py (percentile/absolute modes), momentum_ranker.py (12-1 blended), portfolio_builder.py (full pipeline + backtest engine). 32/32 tests. Live portfolio: 15 stocks from 90-ticker universe. BACKTEST: +320.9% total return vs SPY +148.4% (+172.5% alpha), 25.2% annualized, Sharpe 0.86. KEY: momentum rotation on quality-screened pool captures trends while avoiding junk. LIMITATION: quality fundamentals are current, not historical.
   **Phase G — Build ETF Comparison Backtest: COMPLETE (2026-06-08)** — Built factor_tilts/etf_comparison_backtest.py: 8-ETF universe (added VFMF), 9 blended strategies, walk-forward validation, grid-searched optimal weights, regime analysis. 39/39 tests. Live results (2019-2026): VLUE best B&H (+178.7%, Sharpe 0.578, +5.6% alpha vs SPY). Core-Satellite AVUV best blended (+178.8%, Sharpe 0.587, +5.7% alpha). KEY FINDINGS: (1) Grid search optimal = 100% SPY for 2-ticker combos — SPY dominates Sharpe in 2019-2026 bull market. (2) Value/Momentum factors underperformed large-cap growth in this period. (3) Core-Satellite AVUV best balanced approach: +5.7% alpha with -37.9% DD vs SPY's -33.7%. (4) Regime analysis: factors shine in bear markets (Value Momentum Blend: -21.1% bear DD vs SPY -26.0%) but lag in bull markets. CONCLUSION: Factor tilts provide better drawdown protection, not raw alpha in growth-led bull markets.
   **Phase H — Automated Rebalancing Engine:** Build Python module that: (1) screens stocks quarterly per sequential filter, (2) generates buy/sell/hold recommendations, (3) calculates tax implications for taxable accounts, (4) sends email report to Daryl with recommendations and performance update.
   **Output:** Updated `BEATING_BUY_HOLD.md` + Python backtest modules in `stock_market_prediction/factor_strategies/`
   **Multi-turn work: YES.**

- [ ] **2026-06-08 — Factor Tilts Prototype (PRIORITY #3, FOLLOW-UP TO RESEARCH)** — COMPLETE
    Built stock_market_prediction/factor_tilts/: scorers.py (value/momentum/quality), magic_formula.py (Greenblatt screener), etf_factor_backtest.py (ETF backtester)
    33/33 tests. Live backtest: 10 ETFs, 8 strategies, 2020-2026.
    KEY FINDING: AVUV (small-cap value) +231.7% vs SPY +159.9% (+71.8% alpha). Core-Satellite (SPY+AVUV+QMOM) best Sharpe at 0.749.
    Next: Magic Formula stock-level screener with real data (requires financial data API — may need yfinance fundamentals).

- [ ] **STANDING — Email inbox management (PRIORITY #1 & #2, EVERY TURN)**
  1. **From Daryl (daryl.allen.jr@gmail.com or allend43@gmail.com):** Respond directly. Research, look up local files, or reply as appropriate. This overrides all other directives.
  2. **From anyone else:** Forward the full email to daryl.allen.jr@gmail.com with subject `[FWD - agent-daryl] <original subject>`. Wait for Daryl's instructions before responding to non-Daryl senders.

- [ ] **2026-06-05 — Model Router (QoL #20) — COMPLETE**
    Built tools/shared/model_router.py: intelligent task routing across local (llama.cpp), Gemini, and OpenRouter. Complexity-based routing, circuit breakers, graceful degradation, persistent stats. 30/30 tests. CLI interface. Live routing verified.

- [ ] **2026-06-05 — Bug fix: send_html_email.py --subject flag — COMPLETE**
    Fixed argparse dest collision between --subject flag and positional subject arg. Both modes now work.

- [ ] **2026-06-05 — Stock Market Prediction Project (PRIORITY #3, OVERALL FOCUS)**
    Build ML-based stock prediction system for self-funding. Research complete at `future_project_ideas/stock_market_prediction/RESEARCH_DESIGN.md`.
    **Phase 1: COMPLETE (2026-06-05)** — Packages installed. Data pipeline with yfinance working (SPY/QQQ/IWM/GLD/TLT + VIX). Feature engineering: 55 technical indicators across 7 categories (trend, momentum, volatility, volume, price, cross-MA, regime). Walk-forward validation framework with return simulation. 33/33 tests. Live pipeline tested end-to-end with SPY data.
    **Phase 2: COMPLETE (2026-06-05)** — LightGBM direction classifier (60.4% acc, 0.513 AUC). LSTM trend detector (61.0% acc, attention mechanism). Regime classifier (96.8% acc, SMA-based labeling, class-balanced). Hyperparameter tuning (5 configs). 64/64 total tests. Key insight: ~60% direction accuracy is expected — edge comes from risk management, not prediction.
    **Phase 3: COMPLETE (2026-06-05)** — Regime-aware ensemble (LightGBM+LSTM weighted by regime classifier). Kelly criterion position sizing (0.5x fractional, regime-adjusted). Stop-loss/risk management (hard 3%, trailing 2%, take-profit 6%, time 20d). Risk sim: +0.47% return, -2.58% max DD, Sharpe 0.63, 33 trades, 48.5% win rate. 109/109 tests total. Underperforms B&H but has far lower drawdown.
    **Phase 4: COMPLETE (2026-06-05)** — Full walk-forward backtest: 62 rolling folds (2019-2026), 917 trades, -27.3% strategy return vs +237.4% B&H. 17/62 folds beat B&H (27.4%). Mean accuracy 52.2%, Sharpe -6.61, Max DD -28.6%. Key insight: system's value is drawdown control, not alpha. In bull markets, frequent exits = missed upside.
    **Phase 5 MR Prototype: COMPLETE (2026-06-05)** — Mean-reversion strategy: BB z-score + RSI signals with trend circuit breaker. Full-sample: +5.6% return, 55.6% win rate, PF 1.57, Sharpe 0.25, Max DD -4.36%, only 18 trades over 8 years. Walk-forward: 32.3% folds beat B&H. KEY FINDING: MR is PROFITABLE (vs ensemble's -27.3%) but still loses to B&H (+237.4%) — sits in cash during bull trends. 29/29 tests.
    **STRATEGIC PIVOT (2026-06-06)** — Qwen 3.7 Max analysis received. Two paths forward:
    **Path A: GPU Compute (Vast.ai)** — $200-250/mo net, >95% success probability. BLOCKED: conflicts with local inference on AI-box. Needs Daryl's decision.
    **Path B: Dual Momentum Trading** — Pivot from ML to momentum rotation strategy.
    **Phase 6 DM v1: COMPLETE (2026-06-06)** — Blended momentum scoring, absolute momentum filter, monthly rebalance. +126.2% return, -34.6% DD, 5% cash. Underperforms B&H SPY (+396%) but is profitable.
    **Phase 7 DM v2: COMPLETE (2026-06-06)** — 200-SMA circuit breaker, walk-forward validation. +238.8% return, -31.3% DD, 12.7% cash, Sharpe 0.575. Walk-forward: 57.1% folds beat SPY, mean alpha -0.17% (essentially flat). KEY: circuit breaker dramatically improved strategy.
    **Phase 8:** Paper trading with Alpaca Markets (BLOCKED — needs API key from Daryl + strategic direction).
    **Target:** 1.5-3% monthly return on $1,000 paper account ($15-30/month revenue) OR $200-250/mo via Vast.ai GPU hosting.
    **Blockers:** Need Daryl's decision on Vast.ai vs local inference. Need Alpaca Markets API key.

- [ ] **2026-06-05 — PR #30293 monitoring** (Priority: Low)
  Check PR status every 3 days. Log result. If merged or closed, notify Daryl via email.
  - 2026-06-08: Still open, no reviews, no assignees. 5 pending CI checks.
  - Next check: 2026-06-11

- [ ] **2026-06-05 — [TEMPORARY] Send turn report email after every turn** (Priority: High)
  After every unattended turn, email daryl.allen.jr@gmail.com an HTML report of what you did. This is temporary — Daryl wants to observe behavior during the experimental phase. Will likely be changed to daily/weekly rollup later.

## Completed Directives

<!-- Move completed items here with completion date -->

- [x] **2026-06-05 — Self-exploration #14: Context Budget Tracking** (Priority: Medium) — COMPLETED 2026-06-05
  Built token waste detection module. Tracks operations (reads, searches, LLM calls, web fetches), detects duplicates/oversize/redundancy, generates reports with recommendations. 43/43 tests. Library + CLI API. File: tools/shared/context_budget.py

- [x] **2026-06-05 — Spades Agent RL: Phase 2 training infrastructure** (Priority: Medium) — COMPLETED 2026-06-05
  Built full PPO training stack: Gymnasium env (375-dim obs), Actor-Critic network, PPO agent with GAE, training loop with TensorBoard.
  30/30 tests passing. Training demo: 777 episodes, best reward 9.60, 100% legal action rate.
  Files: training/gym_env.py, training/networks.py, training/ppo.py, training/trainer.py, tests/test_training.py

- [x] **2026-06-05 — Push langgraph_agents to GitHub** (Priority: High) — COMPLETED 2026-06-05
  Pushed with MIT license and shields.io badges. https://github.com/agent-daryl/langgraph-agents

- [x] **2026-06-05 — GitHub README improvements** (Priority: Low) — COMPLETED 2026-06-05
  Added badges and LICENSE to langgraph-agents. ml-pipeline-service doesn't exist locally.

- [x] **2026-06-05 — MLOps portfolio project #3: OpenShift Health Monitor** (Priority: High) — COMPLETED 2026-06-05
  Built cluster health monitoring system. 4 checkers, rule-based + LLM analyzers, FastAPI, Prometheus.
  24/24 tests passing. Full OpenShift deployment manifests. Pushed to GitHub.
  https://github.com/agent-daryl/openshift-health-monitor

- [x] **2026-06-05 — MLOps portfolio project #1** (Priority: High) — COMPLETED 2026-06-05
  Built end-to-end ML pipeline: data ingestion → model training → serving → monitoring. Python, FastAPI, Prometheus. Docker. Pushed to GitHub.
  - Repo: https://github.com/agent-daryl/ml-pipeline-service
  - Model: GradientBoostingRegressor, R2=0.829, RMSE=0.480
  - Tests: 9/9 passing
  - Endpoints: /predict, /health, /metrics, /validate

- [x] **2026-06-05 — Skill-style docs** (Priority: Medium) — COMPLETED 2026-06-05
  Created SKILL.md docs for all 5 tools with anti-patterns, quality rules, and examples.
  - Web_Search/SKILL.md, Browser_Emulator/SKILL.md, Vision_Analyzer/SKILL.md
  - llm-email-automation/SKILL.md (committed to repo), AI_Box_Access/SKILL.md

- [x] **2026-06-05 — Multi-agent landscape research** (Priority: Medium) — COMPLETED 2026-06-05
  Comprehensive research report with comparison matrix, deep dives, and recommendations.
  - Report: tools/unattended/logs/research/multi-agent-landscape-2026-06-05.md
  - Recommendation: LangGraph first, then CrewAI, watch Mastra for K8s-native agents

- [x] **2026-06-05 — MLOps portfolio project #2: LangGraph agent workflow** (Priority: High) — COMPLETED 2026-06-05
  Built multi-agent workflow: code review + documentation + testing agents. 14/14 tests passing.

- [x] **2026-06-05 — EX280 study progress** (Priority: Medium) — COMPLETED 2026-06-05
  Created 35 flashcards and 10 practice scenarios for EX280 weak areas.
