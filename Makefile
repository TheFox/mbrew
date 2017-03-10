
MKDIR = mkdir -p
RM = rm -rf

.PHONY: all
all: .env man/mbrew.1

man/mbrew.1: man/mbrew.1.ronn
	ronn -w --date=$(shell date +"%Y-%m-%d") --manual='MusicBrew Manual' --organization='FOX21.at' $<

.PRECIOUS: .env
.env:
	echo 'RSYNC_HOST=' >> $@
	echo 'RSYNC_USER=' >> $@
	echo 'RSYNC_REMOTE_PATH=' >> $@

.PRECIOUS: tmp
tmp:
	$(MKDIR) $@

.PHONY: clean
clean:
	$(RM) man/mbrew.1 man/mbrew.1.html
