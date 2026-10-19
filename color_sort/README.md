# color_sort

Everpuzz 1本目(色ソート・仮称)のルール・面生成・検証。純Dart。
Flutter の UI(容器描画・タップ・注ぎアニメ)は、この上に別途載せる。

- `lib/src/rules.dart`: `ColorSortRules`(`PuzzleRules` 実装。ルールはここ1か所)
- `lib/src/generator.dart`: 難易度カーブ(`paramsForIndex`)と逆生成(面番号→決定的な面)
- `assets/levels/pack_main.json`: 同梱レベル(20面、ソルバーで検証済み・`verified` 付き)

```
dart run tool/generate_levels.dart   # 生成+検証してJSONを書き出す
dart run tool/check_levels.dart      # 出荷前検査(全面を再検証。CIでも実行)
dart test
```

## 方針

- 逆操作は合法と限らないため、**最終的な正はソルバー検証**(解けない面は破棄/不合格)
- 完成した容器は動かさない・単色を空容器へ移さない、で探索を削減(解の存在は保つ)
- 未実装: 特殊容器(鍵付き・凍結)、色覚対応の記号、21面目以降(6〜7色は探索上限の調整が必要)
