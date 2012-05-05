

.PHONY: help test


help:
	@sed -n "/^#- /s///p" Makefile



#- Build commands are:
#- 
#-    test            Run tests
#- 

test:
	@./tests/run_tests.sh && echo "All tests passed!"



