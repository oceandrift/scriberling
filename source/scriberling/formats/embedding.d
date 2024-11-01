/++
	Embedded App processing
 +/
module scriberling.formats.embedding;

import scriberling.data.dom;
import scriberling.types;

@safe:

void analyzeEmbeddedAppNode(hstring name, hstring data) pure {

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

Node analyzeMD(hstring data) pure {
	import scriberling.formats.md.parser;

	return parseMD(data);
}

Node analyzeHTML(hstring data) {
	import scriberling.formats.html.parser;

	return parseHTML(data);
}

Node analyzeSDF(hstring data) {
	import scriberling.formats.sdf.parser;

	return parseSDF(data);
}
