
.PHONY: all
all: man/mbrew.1

man/mbrew.1: man/mbrew.1.ronn
	ronn -w --date=$(shell date +"%Y-%m-%d") --manual='MusicBrew Manual' --organization='FOX21.at' $<
