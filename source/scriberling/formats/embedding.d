/++
	Embedded App processing
 +/
module scriberling.formats.embedding;

import scriberling.data.dom;
import scriberling.types;

@safe pure:

Node analyzeEmbeddedAppNode(hstring app, hstring data) {

	static string makeExceptionMessage(hstring app) {
		return "No app available to process embedded block of type `" ~ app ~ "`.";
	}

	switch (app) {
	case "html":
	case "raw":
	case "script":
	case "style":
		return analyzeHTML(data);

	case "scriberling":
		return analyzeSDF(data);

	default:
		throw new Exception(makeExceptionMessage(app));
	}
}

Node analyzeHTML(hstring data) {
	import scriberling.formats.html.parser;

	return parseHTML(data);
}

Node analyzeSDF(hstring data) {
	import scriberling.formats.sdf.parser;

	return parseSDF(data);
}
