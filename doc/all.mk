#
#  Check if we can build the documentation.
#
#  We try to build it, but turn off the build unless
#  all of the prerequisites have been found.
#
WITH_DOCS=yes

ifeq "$(ASCIIDOCTOR)" ""
WITH_DOCS=no
endif

ifeq "$(PANDOC)" ""
WITH_DOCS=no
endif

ifeq "$(docdir)" "no"
WITH_DOCS=no
endif

ifeq "$(WITH_DOCS)" "yes"

#
#  Running "shell" is expensive on OSX.  Building the documentation
#  requires running a bunch of shell commands, because we're too lazy
#  to fix that.  So, only run those shell scripts if we're going to
#  build the documentation.
#
BUILD_DOC := $(strip $(foreach x,doc html pdf adoc install clean,$(findstring $(x),$(MAKECMDGOALS))))
ifneq "$(BUILD_DOC)" ""

install: install.doc

clean: clean.doc

#
#  Our "conf to asciidoc" stuff.
#
CONF_FILES := $(filter-out %~,$(wildcard raddb/*conf raddb/mods-available/* raddb/sites-available/* raddb/dictionary))
ADOC_FILES := $(patsubst raddb/%,doc/raddb/%.adoc,$(CONF_FILES))
ADOC_FILES += $(patsubst raddb/%.md,doc/raddb/%.adoc,$(shell find raddb -name "*\.md" -print))
ADOC_FILES += $(wildcard doc/unlang/*.adoc)
PDF_FILES := $(patsubst doc/%.adoc,doc/%.pdf,$(ADOC_FILES))
HTML_FILES := $(patsubst doc/%.adoc,doc/%.html,$(ADOC_FILES))

#
#  There are a number of pre-built files in the doc/ directory.  Find those.
#
DOC_FILES	:= $(filter-out %~ %/all.mk %.gitignore doc/rfc/update.sh doc/source/%,$(shell find doc -type f))

#
#  We sort the list of files, because the "find" command above will
#  output pre-build ADOC / HTML files that may be laying around.  We
#  don't want duplicate rules.  We do want to build and install the
#  ADOC / HTML files, even if they don't (or do ) already exist.
#
#  We remove the "doc/" prefix, because the documentation files are
#  installed into $(docdir)/foo, and not $(docdir)/doc/.
#
ALL_DOC_FILES	:= $(patsubst doc/%,%,$(sort $(DOC_FILES) $(ADOC_FILES) $(HTML_FILES)))

#
#  Install doc/FOO into $(R)/$(docdir)/FOO
#
$(foreach FILE,$(ALL_DOC_FILES),$(eval $(call ADD_INSTALL_RULE.file,doc/${FILE},$(R)/$(docdir)/${FILE})))

#
#  Have a "doc" install target for testing.
#
install.doc: $(addprefix $(R)/$(docdir)/,$(ALL_DOC_FILES))

.PHONY: clean.doc
clean.doc:
	${Q}rm -f doc/*~ doc/rfc/*~ doc/examples/*~ $(ADOC_FILES) $(HTML_FILES) $(PDF_FILES)

#
#  Markdown files get converted to asciidoc via pandoc.
#
#  Many documentation files are in markdown because it's a simpler
#  format to read/write than asciidoc.  But we want a consistent "look
#  and feel" for the documents, so we make all of them asciidoc.
#
doc/raddb/%.adoc: raddb/%.md
	@echo PANDOC $^
	@mkdir -p $(dir $@)
	@$(PANDOC) --filter=scripts/asciidoc/pandoc-filter -w asciidoc -o $@ $^

#
#  Conf files get converted to Asciidoc via our own magic script.
#
doc/raddb/%.adoc: raddb/%
	@echo ADOC $^
	@mkdir -p $(dir $@)
	@perl -pi -e 's/^# ([^ \t])/#  $$1/;s/^([ \t]+)# ([^ \t])/$$1#  $$2/;s/[ \t]+$$//' $^
	@./scripts/asciidoc/conf2adoc -a ${top_srcdir}/asciidoc -o $@ < $^

doc/%.html: doc/%.adoc
	@echo HTML $^
	@$(ASCIIDOCTOR) $< -b html5 -o $@ $<
	@perl -p -i -e 's/\.adoc/\.html/g' $@

doc/%.pdf: doc/%.adoc
	@echo PDF $^
	@$(ASCIIDOCTOR) $< -b docbook5 -o - | \
		$(PANDOC) -f docbook -t latex --${PANDOC_ENGINE}-engine=xelatex \
			-V papersize=letter \
			-V images=yes \
			--template=./scripts/asciidoc/freeradius.template -o $@

doc/%.pdf: doc/%.md
	@echo PDF $^
	@$(PANDOC) -f markdown -t latex --${PANDOC_ENGINE}-engine=xelatex \
		-V papersize=letter \
		--template=./scripts/asciidoc/freeradius.template -o $@ $<

.PHONY: asciidoc html pdf clean clean.doc
asciidoc: $(ADOC_FILES)
html: $(HTML_FILES)
pdf: $(PDF_FILES)
endif
endif
