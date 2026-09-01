# WS002 portable top verification

Repository rootから実行する。

```sh
plan/ws002-fpga-platform/tests/run_iverilog.sh
```

`tb_cbus_pad_adapter`は六つの安全入力64組と九つのdrive request 512組を総当たりし、許可条件が一つでも失われた同じsimulation timestepでpad OE=0、active-low LVC OE=1になることを検査する。

`tb_portable_board_tops`はPrimer/Mega wrapperを同じCバスstimulusで動かし、reset、idle、非選択、選択read/write、power-good低下で同じ出力になることを検査する。local AXI target未実装buildは明示的DECERR targetへ終端されるため、選択readの期待値はCバスbackend error `16'he001`である。

二つのPython検査は、69 endpoint manifest/CSTの再生成一致、一意な70 location（69 endpoint＋clock）、共通top port集合、二つのboard wrapperの構造同一性、`rtl/ip/`へのboard/vendor名の漏出禁止を検査する。

このsimulationは外付けOE pull-up、configuration中のpin state、clock停止、Gowin place-and-route、Cバス電気適合を証明しない。
