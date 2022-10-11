import { GET } from "./api.js";
import { CE, date_format, created_at_format, updated_at_format } from "./util.js";
import EditArticle from "./EditArticle.js";

export default function ArticleList(articles) {
	const edit = (created_at, no) =>
		GET(`article/${date_format(created_at)}/${no}`)
			.then(json => document.querySelector(".editor").replaceWith(EditArticle(json)))
			.catch(alert);

	return CE("table", "article-list",
		CE("tr", { className: "article-list-header" },
			CE("th", null, "作成日時"),
			CE("th", null, "番号"),
			CE("th", null, "タイトル"),
			CE("th", null, "表示"),
			CE("th", null, "形式"),
			CE("th", null, "タグ"),
			CE("th", null, "閲覧数"),
			CE("th", null, "更新日時"),
		),
		articles.map(v => CE("tr", { className: "article-row", onclick: () => edit(v.created_at, v.no) },
			CE("td", { className: "date" }, created_at_format(v.created_at)),
			CE("td", { className: "number" }, v.no),
			CE("td", { className: "title" }, v.title),
			CE("td", { className: "checkbox" }, CE("input", { type: "checkbox", checked: v.visible, disabled: true })),
			CE("td", { className: "format" }, v.format),
			CE("td", null, v.tags?.map(v => `#${v} `)),
			CE("td", { className: "number" }, v.views),
			CE("td", { className: "date" }, updated_at_format(v.updated_at)),
		))
	);
}

let prevEndPoint = undefined;
export function updateArticleList(endPoint = undefined) {
	if (endPoint === undefined) {
		if (prevEndPoint === undefined)
			return;
		endPoint = prevEndPoint;
	}
	GET(endPoint)
		.then(json => {
			document.querySelector(".article-list").replaceWith(ArticleList(json));
			prevEndPoint = endPoint;
		})
		.catch(alert);
}
