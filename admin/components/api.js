class APIError extends Error {
	constructor(...params) {
		super(...params);
		this.name = "APIError";
	}
}

const send = (method, endPoint, body = undefined) => {
	let init = undefined;

	if (method === "POST" || method === "PUT") {
		if (body === undefined)
			throw new APIError("nothing body");
		const isObject = typeof body === "object";
		body = isObject ? JSON.stringify(body) : String(body);
		const headers = new Headers({
			"Content-Type": `application/${isObject ? "json" : "x-www-form-urlencoded"}`,
			"Content-Length": body.length
		});
		init = { method, headers, body };
	}

	return fetch(`api.rb/${endPoint}`, init)
		.then(r => {
			if (!r.ok) throw new APIError("response error");
			return r.json();
		});
}

export const GET = (endPoint) => send("GET", endPoint);
export const POST = (endPoint, body) => send("POST", endPoint, body);
export const PUT = (endPoint, body) => send("PUT", endPoint, body);
export const DELETE = (endPoint) => send("DELETE", endPoint);

export const PREVIEW = body => {
	if (body === undefined)
		throw new APIError("nothing body");

	body = JSON.stringify(body);

	return fetch("preview.rb/", {
		method: "POST",
		headers: {
			"Content-Type": "application/json",
			"Content-Length": body.length
		},
		body
	})
		.then(r => {
			if (!r.ok) throw new APIError("response error");
			return r.text();
		});
};
