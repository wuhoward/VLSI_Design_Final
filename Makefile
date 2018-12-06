VLOG    = ncverilog
SYNVLOG = ncverilog +ncmaxdelays
SRC     = testfixture1.v sram_16384x8.v SAO.v
SYNSRC  = testfixture1.v SAO_syn.v sram_16384x8.v -v tsmc13_neg.v
APRSRC  = testfixture1_postlayout SAO_pr.v sram_16384x8.v -v tsmc13_neg.v
VLOGARG = +nospecify +notimingchecks +access+r 
SYNARG  = +define+SDF +access+rw 
TMPFILE = *.log ncverilog.key nWaveLog
DBFILE  = *.fsdb *.vcd *.bak
RM      = -rm -rf

all :: sim

apr :
	$(SYNVLOG) $(APRSRC) $(SYNARG)

sim :
	$(VLOG) $(SRC) $(VLOGARG)
 
syn :
	$(SYNVLOG) $(SYNSRC) $(SYNARG)
 
check :
	$(VLOG) -c $(SRC)
 
clean :
	$(RM) $(TMPFILE)
	
veryclean :
	$(RM) $(TMPFILE) $(DBFILE)
