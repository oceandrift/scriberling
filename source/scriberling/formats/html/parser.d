module scriberling.formats.html.parser;

import scriberling.data.dom;
import scriberling.types;

@safe pure:

RawNode parseHTML(hstring data) {
	auto node = new RawNode();
	node.innerHTML = data;

	return node;
}
