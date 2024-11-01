module scriberling.site.config;

///
struct SiteConfig {
	///
	bool[string] voidElements;
}

///
static immutable SiteConfig defaultSiteConfig = () {
	//
	auto cfg = SiteConfig();
	cfg.applyHTML5VoidElements();
	return cfg;
}();

@safe:

private void applyHTML5VoidElements(ref SiteConfig cfg) {
	cfg.voidElements["area"] = true;
	cfg.voidElements["base"] = true;
	cfg.voidElements["br"] = true;
	cfg.voidElements["col"] = true;
	cfg.voidElements["embed"] = true;
	cfg.voidElements["hr"] = true;
	cfg.voidElements["img"] = true;
	cfg.voidElements["input"] = true;
	cfg.voidElements["link"] = true;
	cfg.voidElements["meta"] = true;
	cfg.voidElements["param"] = true;
	cfg.voidElements["source"] = true;
	cfg.voidElements["track"] = true;
	cfg.voidElements["wbr"] = true;
}
