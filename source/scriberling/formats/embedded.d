/++
	Embedded App Nodes
 +/
module scriberling.formats.embedded;

import scriberling.data.dom;
import scriberling.formats.embedding;
import scriberling.types;

///
final class EmbeddedAppNode : Node {

	public {
		hstring app;
		hstring data;
		Location location;
	}

	///
	override void analyze(const SiteConfig siteConfig) pure {
		auto substitute = analyzeEmbeddedAppNode(app, data, siteConfig);
		this.parent.replaceChild(this, substitute);
	}

	override void compile(Sink sink) {
		throw new Exception("Cannot compile unanalyzed embedded-app node.");
	}
}
