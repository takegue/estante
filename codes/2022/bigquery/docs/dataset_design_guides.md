複数のチーム、複数人によるデータセットの管理においては

# Consistency is imperative quality for User Experience

一貫性はデータセット開発者が最も注意すすべき品質である。
すべてのデータセットは一定の規則を元に構築されていることが望ましい。
これは命名やドキュメンテーション、メタデータ管理に関する一貫性を必要とする。

なぜこれらに配慮する必要があるかこれは利用者に最も便益を生むためである。
ユーザは、データセット、テーブル、カラムなどの一覧を見るだけで
直感的かつ書くべきSQLが想像できることが好ましい。
また機能の「不足/不可能」がつたわることも重要なポイントである。

SQLによる分析はテーブルの結合操作により利用来ることが多い。
単一のデータセットによってすべての分析をまかなうことは難しいため
単一のデータセットに限らない一貫性が必要である。

- Simple
- Composable
- Predictable
- Backwards compatible

# Consistency is imperative quality for User Experience

# Dataset as API

公開されたデータセット上に配置されるすべてのテーブルおよびルーティンはAPIとしての運用が必要となる。

https://cloud.google.com/apis/design

### Useful widetable rather than normalized table

同一のPKを持つ複数のテーブルをユーザに公開することは避けるべきである。
ひとつのテーブルであることは単一データセットの複数テーブルであることよりよく
単一データセットの複数テーブルであることは、複数データセットは複数データセット複数テーブルであることよりよい。
ユーザが担うべき認知負荷は最小になるとよい。

ユーザが利用するテーブルは正規化されたテーブルを個別にJOINさせるような
一つのテーブルにおいてすべてのカラムがそろっているワイドテーブルを目指す方がよい。
同一のデータセットのテーブル内において、同一のPKを持つテーブルの複数用意し
ユーザに使い分けやJOINを強いることはなるべく避けた方がよい。

新鮮さや整合性のために
マテリアライズドビューや

### 命名による並び替えを意識する

データセット、テーブルは制約上 Alphabetical Orderにより表示される。
人間か認知できるのはせいぜい4-5個の片手で数えられる数だけである。
これは利用者の目線に立つと大きい制約である。

利用頻度が高くなるデータセットおよびテーブルほど、並び順が最初にこなければならない。

次のような単語を利用するとよいだろう。

- core
-

### Resource Access Modification

多種多様なデータセットの共有において最も避けるべき複雑さは依存の管理による複雑さである。
「依存されうるものは依存される」という [[Hyrumの法則]] にしたがって
データセット開発者は依存される要素を減らすことが望ましい。

特定のデータセットに対して、ユーザが利用すべきテーブルと利用すべきではないテーブルは命名から自明でわかるとよい。
「命名による並び替えを意識する」と合わせて考えると prefixとして zなどを用いることで
ユーザが利用すべきテーブルが上位に来る。

```
dataset
|- core: ユーザが利用利用可能なPraimary Table
|- zcore__segment1: ユーザ利用を許容しないテーブル1. coreの構築に必要なテーブル
|- zcore__segment2: coreを作成するために必要なセグメント定義2
...
```

# Practical Dataset Design Pattern

### Entity

特定のPKに対する属性情報を取りまとめたデータセットである。

- PKに対する保守された最新情報を公開するテーブル
- Slowly Changing Dimension に対する履歴機能つきのテーブル

```
ent__[entity_nane]
|-@routine
|  | - history: as-wasの復元データの公開テーブル
|- core: as-isの公開テーブル
|- zcore__: データ定義
|- zhistory: データ定義
|- zindex__segmentX: materialized_viewによるクラスタインデックス
|- zmonitor__YYYY: 品質確認用に用いられるデータソースに関するサマリーテーブル
```

### Sink Source Table

このデータセットはデータソースに対するまとめあげまたはユースケースにもどついたデータソースの分割を担う。

```
log__[log_nane]
|- all
|- android
|- iOS
|- web
|- zmonitor__YYYY: 品質確認用に用いられるデータソースに関するサマリーテーブル
```


# Consistency is imperative quality for User Experience

# Related Other Architecture

## Data Vault 2.0

これはあくまで実装に対するプラクティスであり、ユーザにとって優れたインタフェースを提供するための考え方ではない。
特にRaw Vaultはユーザ向きではない。 (Data Vault 2.0自身も Data Martの存在を仮定している。)

SatelliteやHubは ユーザが利用する際には、 ひとつのワイドテーブルになっていることが望ましい。

またLinkテーブルは1:1, N:N, 1:Nの曖昧性を解消することはできないし1:1においても曖昧性が残るため
スキーマだけでは曖昧性を解消しきれないコンテキストの高いテーブルである。これはユーザにとっても利用のしづらさを生む


## Data Governance for Security

### Dataset Access Control


## References

- [Stripe Sessions 2019 | How Stripe builds APIs and teams](https://www.youtube.com/watch?v=IEe-5VOv0Js)