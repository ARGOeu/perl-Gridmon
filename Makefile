#
# dummy Makefile to allow Koji to execute "make sources"
#
MAKEFILE=Makefile.tmp
sources:
	perl Makefile.PL MAKEFILE=$(MAKEFILE)
	touch META.yml
	make -f $(MAKEFILE) dist
	rm -f $(MAKEFILE)
