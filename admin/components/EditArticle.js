import { GET, POST, PUT, DELETE, PREVIEW } from "./api.js";
import { CE, date_format, calendar_format, updateMonthSelector } from "./util.js";
import BlogError from "./BlogError.js";
import { updateArticleList } from "./ArticleList.js";

export default function EditArticle(targetArticle = undefined) {
	GET("tags")
		.then(json => {
			const e = document.querySelector(".exist-tags");
			const onclick = (name) => {
				const e = document.querySelector(".tags");
				if (e.value.indexOf(name) == -1) {
					if (e.value.length > 0)
						e.value += " ";
					e.value += name;
				}
			};
			e.textContent = "";
			json.map(tag => e.appendChild(CE("a", { className: "add-tag", onclick: () => onclick(`#${tag}`) }, `#${tag}`)));
		})
		.catch(alert);

	const formatOptions = [
		CE("option", { value: "GFM" }, "GFM"),
		CE("option", { value: "Wiki" }, "Wiki")
	];

	const defaultFormat = targetArticle ? targetArticle?.format : "GFM";
	const o = formatOptions.find(v => v.value === defaultFormat);
	if (o)
		o.selected = true;

	const getSendData = () => {
		const base = document.querySelector(".editor");
		const created_at = base.querySelector(".created_at").value;
		const title = base.querySelector(".title").value;
		const tags = base.querySelector(".tags").value.split("#").filter(v => typeof v === "string" && v.length > 0).map(v => v.trim()).filter(v => v.length > 0);
		const format = base.querySelector(".format").value;
		const body = base.querySelector(".body").value;
		const visible = base.querySelector(".visible").checked;
		if (typeof title !== "string" || title.length === 0 || typeof body !== "string" || body.length === 0)
			throw new BlogError("タイトルまたは本文がありません");
		return { created_at, title, tags, format, body, visible };
	}

	const onpreview = () => {
		PREVIEW(getSendData())
			.then(text => {
				const previewBox = document.querySelector(".preview-box");
				previewBox.innerHTML = text;
				previewBox.scrollIntoView({
					behavior: "smooth",
					block: "start",
					inline: "center"
				});
			})
			.catch(alert);
	}

	const onsubmit = () => {
		const sendData = getSendData();
		if (targetArticle) {
			delete sendData.created_at;
			for (const name of ["title", "tags", "format", "body", "visible"]) {
				const l = sendData[name] instanceof Array ? sendData[name].sort().join() : sendData[name];
				const r = targetArticle[name] instanceof Array ? targetArticle[name].sort().join() : targetArticle[name];
				if (l === r) delete sendData[name];
				else targetArticle[name] = sendData[name];
			}
		}
		if (Object.keys(sendData).length === 0)
			throw new BlogError("変更箇所がありません");
		const update = targetArticle !== undefined && "created_at" in targetArticle && "no" in targetArticle;
		const post = update
			? PUT(`article/${date_format(targetArticle.created_at)}/${targetArticle.no}`, sendData)
			: POST("article", sendData);
		post.then(json => {
			if (!json.result)
				throw new Error(`${update ? "更新" : "投稿"}に失敗しました`);
			updateMonthSelector();
			updateArticleList();
			onpreview();
			if (!targetArticle) {
				targetArticle = sendData;
				targetArticle.no = json.no;
				document.querySelector(".created_at").disabled = true;
				document.querySelector(".delete").disabled = false;
			}
		}).catch(alert);
	}

	const ondelete = () => {
		DELETE(`article/${date_format(targetArticle.created_at)}/${targetArticle.no}`)
			.then(json => {
				if (!json.result)
					throw new Error("削除に失敗しました");
				targetArticle = undefined;
				document.querySelector(".created_at").disabled = false;
				document.querySelector(".delete").disabled = true;
				document.querySelector(".preview-box").textContent = "";
				updateMonthSelector();
				updateArticleList();
			}).catch(alert);
	}

	const previewBox = document.querySelector(".preview-box");
	previewBox.textContent = "";

	return CE("div", "editor",
		CE("div", "paragram",
			CE("input", { className: "created_at", type: "date", disabled: targetArticle !== undefined, value: calendar_format(targetArticle?.created_at) }),
			CE("input", { className: "title", type: "text", placeholder: "タイトル", value: targetArticle?.title }),
		),
		CE("div", "paragram",
			CE("input", { className: "tags", type: "text", placeholder: "タグ（複数指定する場合は#で区切ります）", value: targetArticle?.tags?.map(v => `#${v}`).join(" ") }),
			CE("label", null,
				"既存タグ: （クリックするとタグ欄に追加します）",
				CE("div", "exist-tags", "...loading...")
			)
		),
		CE("div", "paragram",
			CE("label", { className: "label" },
				"書式: ",
				CE("select", { className: "format", id: "format" }, formatOptions)
			),
			CE("textarea", { className: "body", placeholder: "本文", value: targetArticle?.body }),
		),
		CE("div", "paragram",
			CE("label", { className: "label" },
				CE("input", { className: "visible", type: "checkbox", checked: targetArticle?.visible }),
				"記事を公開する"
			),
			CE("button", { className: "submit", onclick: onsubmit }, targetArticle ? "更新" : "送信"),
			CE("button", { className: "preview", onclick: onpreview }, "プレビュー"),
			CE("button", { className: "delete", disabled: targetArticle === undefined, onclick: ondelete }, "削除"),
		)
	);
}
