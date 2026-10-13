/**
 * Rotash 1週間テストのふりかえり用 Google フォームを作る（Google Apps Script）。
 *
 * 使い方
 *   1. https://script.google.com を開き「新しいプロジェクト」を作る
 *   2. 最初からある中身を消して、このファイルをまるごと貼り付けて保存する
 *   3. 上の関数の選択欄で createRotashFeedbackForm を選んで「実行」を押す
 *   4. 初回は権限の確認が出るので、自分のアカウントで許可する
 *   5. 下の「実行ログ」に出る「回答用URL」を友達に送る
 *
 * 回答は新しく作られるスプレッドシートに自動でたまる。
 * 実行するたびに新しいフォームが1つ増えるので、作り直すときは古いほうを消す。
 *
 * # 質問の考え方
 *
 * 「どんな機能がほしい？」はなるべく聞かない（ほしい機能をそのまま作ると、だいたいずれる）。
 * かわりに、実際にしたこと（自分の番じゃない日に開いたか、など）と、そのとき感じたことを聞く。
 * 知りたいのは次の2つの切り分け:
 *   - ルールが分かりにくかっただけなのか（入口の問題）
 *   - 分かっていても、そもそもおもしろくなかったのか（中身の問題）
 */

const FORM_TITLE = 'Rotash 1週間やってみてどうだった？';

function createRotashFeedbackForm() {
  const form = FormApp.create(FORM_TITLE);
  form
    .setDescription(
      '1週間ありがとう！\n' +
      '気をつかわなくていいので、正直に答えてほしい。つまらなかったら「つまらなかった」で全然OK、そのほうが助かる。\n' +
      '5分くらいで終わります。'
    )
    .setProgressBar(true)
    .setCollectEmail(false)
    // Google にログインしていない人でも答えられるように、1人1回の制限はかけない。
    .setLimitOneResponsePerUser(false)
    .setShowLinkToRespondAgain(false)
    .setConfirmationMessage('ありがとう！めっちゃ助かる。');

  // ---- 1ページ目: 基本 ----
  form.addTextItem()
    .setTitle('名前（ニックネームでOK）')
    .setHelpText('空欄でもいいよ');

  // 選んだ答えで次のページを分けるので、選択肢はページを作ったあと（いちばん下）で入れる。
  const joinedWhen = form.addMultipleChoiceItem()
    .setTitle('いつから参加した？')
    .setRequired(true);

  // ---- 2ページ目: 途中から入った人だけ ----
  const midJoinPage = form.addPageBreakItem()
    .setTitle('途中から入った人へ')
    .setHelpText('週の途中からグループに入った人だけのページです。');

  addScale_(form, 'グループに入った直後、次に何をすればいいか分かった？',
    '全然分からなかった', 'すぐ分かった', { required: true });

  addChoice_(form,
    '入った日は撮る番が回ってこない（何もできない）仕組みなんだけど、正直どう思った？', [
      '特に気にならなかった',
      'ちょっと不安だった（ちゃんと入れたか分からない）',
      '壊れてる・失敗したと思った',
      '何もできないことに気づかなかった',
    ], { other: true });

  addParagraph_(form, '入ったあと、最初にしたこと・探したものは？', { help: 'うろ覚えでOK' });

  // ---- 3ページ目: 分かりやすさ（全員） ----
  const clarityPage = form.addPageBreakItem()
    .setTitle('分かりやすさ');

  addCheckbox_(form, 'やってる途中で「これどういうこと？」ってなったものは？（いくつでも）', [
    '自分がいつ撮る番なのか',
    '今日は誰が撮る番なのか',
    '撮り方（どこを押せばいいか）',
    'スマホを横にすると作品が見られること',
    '写真の右下の丸（もう一方のカメラの写真）',
    '7人いないとできないのか',
    '特になかった',
  ], { other: true });

  addChoice_(form, 'スマホを横にすると今週の作品（7分割）が見られるの、いつ気づいた？', [
    'すぐ気づいた',
    '何日かして気づいた',
    '人に言われて知った',
    '今このフォームで初めて知った',
  ], { required: true });

  addParagraph_(form, 'このアプリ、友達に一言で説明するとしたらなんて言う？', {
    help: '正解はないです。どう伝わってるかを知りたい',
    required: true,
  });

  // ---- 4ページ目: おもしろさ（全員） ----
  form.addPageBreakItem()
    .setTitle('おもしろさ')
    .setHelpText('お世辞はいらないです。');

  addScale_(form, '正直、1週間やってみておもしろかった？',
    'つまらなかった', 'めっちゃおもしろかった', { required: true });

  addChoice_(form, '自分の番じゃない日、アプリ開いた？', [
    '毎日のように開いた',
    '何回か開いた',
    'ほぼ開かなかった',
    '一回も開かなかった',
  ], { required: true });

  addParagraph_(form, 'それはなんで？（開いた理由 / 開かなかった理由）');

  addChoice_(form, '「今日は誰が撮るか分からない」のは、どうだった？', [
    'ワクワクした・気になった',
    '特に何とも思わなかった',
    '分かりにくいだけだった',
    'そういう仕組みだと気づいてなかった',
  ]);

  addChoice_(form, '自分の番の日、撮ったきっかけは？', [
    '通知で思い出した',
    '自分で覚えてた',
    '友達に言われた',
    '撮り忘れた',
    '撮れなかった',
  ], { other: true });

  addScale_(form, '自分の番の日、撮るのは面倒だった？', '全然', 'かなり面倒');

  addChoice_(form, '完成した7枚を見てどう思った？', [
    '思ってたよりよかった',
    'まあこんなもんか',
    '微妙だった',
    'まだちゃんと見てない',
  ]);

  addChoice_(form, '完成した作品、ストーリーやLINEに載せたい？', [
    '載せた / 載せたい',
    '誰かが載せるならいい',
    '載せたくない',
  ]);

  addParagraph_(form, '一番楽しかった瞬間は？');
  addParagraph_(form, '一番だるかった・冷めた瞬間は？');

  // 「分かりにくかっただけ」か「そもそもおもしろくない」かを分けるための質問。
  addScale_(form, '仕組みが全部分かった今の状態で、もう1週やったら楽しめそう？',
    '変わらずつまらなそう', 'かなり楽しめそう', { required: true });

  // ---- 5ページ目: これから ----
  form.addPageBreakItem()
    .setTitle('これから');

  addChoice_(form, '来週もこのメンバーでやる？', [
    'やりたい',
    '誘われたらやる',
    'たぶんやらない',
    'やらない',
  ], { required: true });

  addChoice_(form, '別のグループ（家族・部活・バイト先など）でもやってみたい？', [
    'やりたいグループがある',
    'ちょっと思った',
    '思わない',
  ]);

  addParagraph_(form, 'LINEのアルバムやインスタじゃなくて、Rotashでやる意味ってあった？', {
    help: '「なかった」でもOK。あったなら、何が違った？',
  });

  addParagraph_(form, '一個だけ変えられるとしたら、何を変える？');

  // ---- 6ページ目: 最後 ----
  form.addPageBreakItem()
    .setTitle('最後に');

  addParagraph_(form, '文句・バグ・言い残したこと、なんでも');

  // ---- 1ページ目の分かれ道 ----
  // 最初からいた人は「途中から入った人へ」を飛ばして「分かりやすさ」へ進む。
  joinedWhen.setChoices([
    joinedWhen.createChoice('最初から（グループができたときから）', clarityPage),
    joinedWhen.createChoice('週の途中から', midJoinPage),
  ]);

  // ---- 回答をスプレッドシートにためる ----
  const sheet = SpreadsheetApp.create(FORM_TITLE + '（回答）');
  form.setDestination(FormApp.DestinationType.SPREADSHEET, sheet.getId());

  // 新しく作ったフォームが「未公開」のままになる場合があるので、使える環境では公開にしておく。
  if (typeof form.setPublished === 'function') {
    form.setPublished(true);
  }
  form.setAcceptingResponses(true);

  Logger.log('回答用URL（友達に送る）: ' + form.getPublishedUrl());
  Logger.log('編集用URL（自分用）: ' + form.getEditUrl());
  Logger.log('回答がたまるシート: ' + sheet.getUrl());
}

// ---- 質問を足すための小さな関数 ----

/** 1つだけ選ぶ質問。 */
function addChoice_(form, title, choices, opts) {
  opts = opts || {};
  const item = form.addMultipleChoiceItem()
    .setTitle(title)
    .setChoiceValues(choices)
    .setRequired(!!opts.required);
  if (opts.other) item.showOtherOption(true);
  if (opts.help) item.setHelpText(opts.help);
  return item;
}

/** いくつでも選べる質問。 */
function addCheckbox_(form, title, choices, opts) {
  opts = opts || {};
  const item = form.addCheckboxItem()
    .setTitle(title)
    .setChoiceValues(choices)
    .setRequired(!!opts.required);
  if (opts.other) item.showOtherOption(true);
  if (opts.help) item.setHelpText(opts.help);
  return item;
}

/** 1〜5 の目盛りで答える質問。 */
function addScale_(form, title, lowLabel, highLabel, opts) {
  opts = opts || {};
  const item = form.addScaleItem()
    .setTitle(title)
    .setBounds(1, 5)
    .setLabels(lowLabel, highLabel)
    .setRequired(!!opts.required);
  if (opts.help) item.setHelpText(opts.help);
  return item;
}

/** 自由に書く質問。 */
function addParagraph_(form, title, opts) {
  opts = opts || {};
  const item = form.addParagraphTextItem()
    .setTitle(title)
    .setRequired(!!opts.required);
  if (opts.help) item.setHelpText(opts.help);
  return item;
}
