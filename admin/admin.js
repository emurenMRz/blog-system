import { updateMonthSelector, updateTagSelector } from "./components/util.js";
import EditArticle from "./components/EditArticle.js";
import { updateArticleList } from "./components/ArticleList.js";

addEventListener("load", () => {
	const addArticle = document.getElementById("add-article");
	addArticle.addEventListener("click", () => document.querySelector(".editor").replaceWith(EditArticle()));
	addArticle.click();

	updateArticleList(`articles/newly`);

	const selectorMonth = document.getElementById("select-month");
	selectorMonth.addEventListener("change", () => {
		const month = selectorMonth.value.split("-").join("");
		if (month.length === 0) return;
		updateArticleList(`articles/${month}`);
	});
	updateMonthSelector();

	const selectorTag = document.getElementById("select-tag");
	selectorTag.addEventListener("change", () => {
		const tag = selectorTag.value;
		if (tag === "---") return;
		updateArticleList(`articles/tag/${tag}`);
	});
	updateTagSelector();

	const viewRanking = document.getElementById("view-ranking");
	viewRanking.addEventListener("click", () => updateArticleList(`articles/views`));

	const newly = document.getElementById("newly");
	newly.addEventListener("click", () => updateArticleList(`articles/newly`));
});
