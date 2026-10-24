# Mozc(fcitx5-mozc-ut)の意図しない変換調査メモ

「していただく」をスペース変換すると「シていただく」のように「し」がカタカナになる現象について調査した記録。「して」という文言を含む読みで発生する。

## 症状

- 読み「して」を含む語をスペース変換すると、「し」の部分だけカタカナ「シ」になった候補が最上位に出る
- `していただく` → `シていただく`
- Ctrl+Delete(候補を学習履行から削除するショートカット)を押しても再発する

## 原因調査

### 1. 個人の学習データが原因か確認(→違った)

Mozc は変換のたびに以下のファイルに学習データを蓄積する。

```text
~/.config/mozc/.history.db   変換履行(予測変換の学習)
~/.config/mozc/segment.db    文節区切りの学習
~/.config/mozc/boundary.db   同上
~/.config/mozc/cform.db      活用形の学習
```

mozc_server を停止し、この4ファイルをバックアップの上で削除 → 再起動して学習データをゼロから再構築させたが、**症状は改善しなかった**。これにより、個人の入力履行が原因ではないと判明した(Ctrl+Delete は上記ファイルのうち主に予測変換の学習にしか作用しないため、そもそも効果がなかった理由も説明できる)。

### 2. システム辞書(fcitx5-mozc-ut)を調査(→これが原因)

このマシンでは [hosts/common/input-method.nix](../hosts/common/input-method.nix) で `fcitx5-mozc-ut` を使用している。これは nixpkgs 上で以下のように定義されている([mozc-ut/package.nix](https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/mo/mozc-ut/package.nix)):

```nix
mozc.override {
  dictionaries = [
    mozcdic-ut-alt-cannadic
    mozcdic-ut-edict2
    mozcdic-ut-jawiki
    mozcdic-ut-neologd        # ← 原因
    mozcdic-ut-personal-names
    mozcdic-ut-place-names
    mozcdic-ut-skk-jisyo
    mozcdic-ut-sudachidict
  ];
}
```

`mozc` パッケージ本体([mozc/package.nix](https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/mo/mozc/package.nix))はビルド時に以下を行う。

```nix
preConfigure = ''
  cd src
''
+ lib.optionalString (dictionaries != [ ]) ''
  cat ${ut-dictionary}/mozcdic-ut.txt >> data/dictionary_oss/dictionary00.txt
'';
```

つまり UT辞書の内容は mozc_server の**システム辞書に直接追記されてコンパイルされる**。個人の学習データとは完全に別物であり、かつ `nix-store -q --references` で見てもこの依存は検出できない(ビルド時に文字列として取り込まれるだけで、実行時の参照としては残らないため)。これが調査を難しくした点。

この中の `mozcdic-ut-neologd` は [mecab-ipadic-NEologd](https://github.com/neologd/mecab-ipadic-neologd) を変換したもので、Web・SNS上のテキストから自動収集した新語辞書であり、**人力でのキュレーションがない**。ネットスラングを広く収録する一方、性的な意味合いを含む俗語が混入することが知られている。「シて」もこの系統の語と考えられる。

## 恒久対応(見送り)

`mozcdic-ut-neologd` だけを除外したカスタム構成に差し替える案:

```nix
fcitx5.addons = with pkgs; [
  (fcitx5-mozc.override {
    mozc = mozc.override {
      dictionaries = [
        mozcdic-ut-alt-cannadic
        mozcdic-ut-edict2
        mozcdic-ut-jawiki
        mozcdic-ut-personal-names
        mozcdic-ut-place-names
        mozcdic-ut-skk-jisyo
        mozcdic-ut-sudachidict
      ]; # mozcdic-ut-neologd を除外
    };
  })
  fcitx5-gtk
];
```

- 標準の `fcitx5-mozc-ut` は nixpkgs の Hydra キャッシュに乗っているためほぼダウンロードのみで済むが、上記のような独自構成は誰も事前にビルドしておらず**ローカルでの mozc 再ビルド(bazel, 数十分規模)が必要**になる
- 一度ビルドすればその `/nix/store` パスはキャッシュされ、以降の `rebuild switch` で毎回再ビルドされるわけではない
- ただし nixpkgs 更新で mozc のバージョンが上がるたびに、この独自構成分は毎回ローカル再ビルドが必要になる(公式キャッシュの対象外のため)

ビルドコストを理由に、今回はこの対応は**見送り**とした。

## 実際に行った対応(ユーザー辞書への登録)

Mozc の辞書ツール(`mozc_tool --mode=dictionary_tool`)でユーザー辞書に以下を追加。

- 読み: `して`
- 単語: `して`
- 品詞: 接続助詞(または名詞)

ユーザー辞書の単語はシステム辞書より優先度が高く扱われるため、「して」の変換で正しいひらがな候補が最上位に出るようになった。**この対応で改善を確認済み。**

## 再発した場合

- 同様の症状が別の読みパターンで出た場合も、同じ手順(辞書ツールでユーザー辞書に正しい変換を単語登録)で個別に対処できる
- 根本的に解決したい場合は、上記の「恒久対応」セクションの `mozcdic-ut-neologd` 除外構成を [hosts/common/input-method.nix](../hosts/common/input-method.nix) に適用し、`sudo nixos-rebuild switch` でビルドし直す
