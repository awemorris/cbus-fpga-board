# Tang board constraint fragments

`primer20k/cbus.cst`と`mega138k/cbus.cst`は、同じtop-level port 69本を各moduleの確認済み3.3 V GPIOへ割り当てる。加えて、Primerの27 MHz clock `H11`、Megaのofficial exampleで使われるclock `V22`を`board_clk`へ割り当てる。

生成・検査:

```sh
python3 plan/ws002-fpga-platform/tests/build_constraints.py --check
```

各`cbus-endpoints.csv`は、CST locationからmodule connector pinまで追跡するmanifestである。Primer locationはSipeed `Tang_Primer_20K_SOM-3961_Schematic.pdf`のFPGA/connector表、Mega locationはSipeed `tang_mega_138k_30353_Schematics.pdf` sheet 6のnet名を正本とした。

これらはpin fragmentであり、完成したproduction constraintではない。Gowin device選択、PLL、timing constraint、drive/slew、configuration pin behaviorは未検証である。特にCSTのpull設定はconfiguration中の安全を保証しない。carrier上の全active-low LVC OEへ外付けpull-upを置き、Gowin合成と無通電/設定中/clock停止を含む実機検査が完了するまでCバスへ接続しない。
