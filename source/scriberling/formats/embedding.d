/++
	Embedded App processing
 +/
module scriberling.formats.embedding;

import scriberling.data.dom;
import scriberling.types;

@safe:

void compileEmbeddedAppNode(hstring name, hstring data) pure {

	static string makeExceptionMessage(hstring name) {
		return "No app available to process embedded block of type `" ~ name ~ "`.";
	}

	switch (name) {
	case "html":
	case "raw":
		break;

	case "scriberling":
		break;

	default:
		throw new Exception(makeExceptionMessage(name));
	}
}

Node compileHTML(hstring data) {
	import scriberling.formats.html.parser;

	return parseHTML(data);
}

Node compileSDF(hstring data) {
	import scriberling.formats.sdf.parser;

	return parseSDF(data);
}
