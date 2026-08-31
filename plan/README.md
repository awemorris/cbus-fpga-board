# CバスFPGAボード計画

最終更新: 2026-08-31

このディレクトリはMWP-Q方式による計画の正本である。

- M書: [master.md](master.md) — 目的、範囲、Milestone、Workstream
- W書: 各 `wsXXX-*/ws.md` — まとまりのある開発成果
- P書: 各 `phaseXXX-*/phase.md` — 実行・検証可能な作業計画
- Q書: [queue.md](queue.md) — ユーザが現在のサイクルで許可した実行項目だけ

計画済みのPhaseは実行許可ではない。実装開始前に、時間枠に収まる有限のQueue案を作り、ユーザの明示的な承認を得る。

## 現在の構造

```text
plan/
├── master.md
├── queue.md
├── ws001-cbus-contract/
├── ws002-fpga-platform/
├── ws003-target-bridge/
├── ws004-soc-runtime/
├── ws005-mailbox-interrupt/
├── ws006-dma-bus-master/
├── ws007-user-ip-sdk/
└── ws008-production-board/
```

## 由来

計画法は [MWP-Q Agentic Coding Method](https://github.com/awemorris/MWP-Q-Agentic-Coding-Method) の日本語版を取り込んだ。エージェント向け全文はリポジトリ直下の `AGENTS.md`、原著のMITライセンス通知は [LICENSE-MWP-Q](LICENSE-MWP-Q) に置く。
