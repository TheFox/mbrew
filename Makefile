
MKDIR = mkdir -p
RM = rm -rf

.PHONY: all
all: .env man/mbrew.1

man/mbrew.1: man/mbrew.1.ronn
	ronn -w --date=$(shell date +"%F") --manual='MusicBrew Manual' --organization='FOX21.at' $<

.PRECIOUS: .env
.env:
	cp .env.example .env

.PRECIOUS: tmp
tmp:
	$(MKDIR) $@

.PHONY: clean
clean:
	$(RM) man/mbrew.1 man/mbrew.1.html
