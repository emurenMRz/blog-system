export default class BlogError extends Error {
	constructor(...params) {
		super(...params);
		this.name = "BlogError";
		alert(params);
	}
}
