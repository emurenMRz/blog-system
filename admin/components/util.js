import { GET } from "./api.js";

export const CE = (tag, props, ...children) => {
	const e = tag ? document.createElement(tag) : document.createDocumentFragment();

	if (props) {
		if (typeof props === "string") {
			if (props[0] === "#")
				e.id = props.substr(1);
			else
				e.className = props;
		} else if (typeof props === "object")
			for (const key in props)
				if (props[key])
					if (key == "style") {
						const style = props[key];
						if (typeof style === "string")
							e.style = style;
						else
							for (const key in style)
								e.style[key] = style[key];
					} else if (key == "dataset") {
						const dataset = props[key];
						for (const key in dataset)
							e.dataset[key] = dataset[key];
					} else
						e[key] = props[key];
	}

	const apply = child => {
		if (child === null || child === undefined) return;
		if (typeof child === "string" || typeof child === "number")
			e.insertAdjacentHTML("beforeend", child);
		else if (child instanceof HTMLElement || child instanceof DocumentFragment)
			e.appendChild(child);
		else if (child instanceof Array)
			for (const a of child)
				apply(a);
	}

	for (const child of children)
		apply(child);
	return e;
};

////////////////////////////////////////

const pad = v => String(v).padStart(2, "0");
export const date_format = date => {
	const s = new Date(date);
	return `${s.getFullYear()}${pad(s.getMonth() + 1)}${pad(s.getDate())}`;
};
export const calendar_format = date => {
	const s = !date ? new Date : new Date(date);
	return `${s.getFullYear()}-${pad(s.getMonth() + 1)}-${pad(s.getDate())}`;
};
export const created_at_format = date => {
	const s = new Date(date);
	return `${s.getFullYear()}/${pad(s.getMonth() + 1)}/${pad(s.getDate())}`;
};
export const updated_at_format = date => {
	const s = new Date(date);
	return `${s.getFullYear()}/${pad(s.getMonth() + 1)}/${pad(s.getDate())} ${pad(s.getHours())}:${pad(s.getMinutes())}:${pad(s.getSeconds())}`;
};

////////////////////////////////////////

function updateSelector(endPoint, elm, reverse, option) {
	GET(endPoint)
		.then(json => {
			const selector = document.getElementById(elm);
			selector.textContent = "";
			selector.appendChild(CE("option", { value: "---" }, elm));
			if (reverse) json.reverse();
			json.map(v => selector.appendChild(option(v)));
		})
		.catch(alert);
}
export function updateMonthSelector() { updateSelector("articles/month", "select-month", true, v => CE("option", { value: v.month }, `${v.month}(${v.count})`)); }
export function updateTagSelector() { updateSelector("tags", "select-tag", false, tag => CE("option", { value: tag }, tag)); }
