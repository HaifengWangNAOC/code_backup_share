INSTALL_DIR=/usr/local/lib/
RM= /bin/rm -vf
CC=gcc
PYTHON=python
IDL=idl

EDCFLAGS:= $(CFLAGS)
EDLDFLAGS:= $(LDFLAGS)

OS=$(shell uname -s)
ifeq ($(OS),Darwin)
	LIBEXT= dylib
	EDCFLAGS:= -arch $(shell uname -m) $(EDCFLAGS)
	EDLDFLAGS:= -arch $(shell uname -m) $(EDLDFLAGS)
else
	LIBEXT= so
endif
TARGETLIB= libextremedeconvolution.$(LIBEXT)


proj_gauss_mixtures_objects= src/bovy_isfin.o src/bovy_randvec.o \
	src/calc_splitnmerge.o src/logsum.o src/minmax.o\
	src/normalize_row.o src/proj_EM.o src/proj_EM_step.o \
	src/proj_gauss_mixtures.o src/splitnmergegauss.o src/bovy_det.o

proj_gauss_main_objects= src/main.o src/parse_option.o src/read_data.o \
		src/read_IC.o src/read_till_sep.o src/write_model.o \
		src/cleanup.o

#
# The next targets are the main make targets: all, 
# extremedeconvolution (the executable), and 
# extremedeconvolution.so (the sharable object library)
#
all: build/extremedeconvolution build/$(TARGETLIB)

build:
	mkdir build

build/extremedeconvolution: $(proj_gauss_mixtures_objects) $(proj_gauss_main_objects) build
	$(CC) -o $@ -lm -lgsl -lgslcblas\
	 $(EDCFLAGS)\
	 $(proj_gauss_mixtures_objects)\
	 $(proj_gauss_main_objects)

build/$(TARGETLIB): $(proj_gauss_mixtures_objects) \
			src/proj_gauss_mixtures_IDL.o build
	$(CC) -shared -o $@ -lm -lgsl -lgslcblas\
	 $(EDLDFLAGS)\
	 $(proj_gauss_mixtures_objects)\
	 src/proj_gauss_mixtures_IDL.o

%.o: %.c
	$(CC) $(EDCFLAGS) -fpic -Wall -c $< -o $@ -I src/

#
# INSTALL THE IDL WRAPPER
#
install: build/$(TARGETLIB)
	cp $< $(INSTALL_DIR)$(TARGETLIB)

idlwrapper:
	echo 'result = CALL_EXTERNAL("$(INSTALL_DIR)$(TARGETLIB)", $$' > tmp
	cat pro/projected_gauss_mixtures_c.pro_1 tmp pro/projected_gauss_mixtures_c.pro_2 > pro/projected_gauss_mixtures_c.pro
	$(RM) tmp

# INSTALL THE PYTHON WRAPPER
pywrapper:
	sed "s#TEMPLATE_LIBRARY_PATH#'$(INSTALL_DIR)'#g" py/extreme_deconvolution_TEMPLATE.py > py/extreme_deconvolution.py


#
# TEST THE INSTALLATION
#
testidl:
	(cd examples && echo 'fit_TF' | $(IDL))
	(cd examples && ((diff TF.tex TF.out && echo 'Ouput of test agrees with given solution') \
	|| echo -e 'Output of test does not agree with given solution\nManually diff the TF.tex and TF.out (given solution) file'))

testpy:
	(cd py && $(PYTHON) extreme_deconvolution.py)


.PHONY: clean spotless

clean:
	$(RM) $(proj_gauss_mixtures_objects)
	$(RM) $(proj_gauss_main_objects)
	$(RM) src/proj_gauss_mixtures_IDL.o

spotless: clean rmbuild
	$(RM) src/*.~
	$(RM) pro/projected_gauss_mixtures.pro
	$(RM) py/extreme_deconvolution.py
	$(RM) pro/projected_gauss_mixtures_c.pro
	$(RM) examples/TF.ps examples/TF.tex

rmbuild: build/
	$(RM) build/extremedeconvolution
	$(RM) build/$(TARGETLIB)
	rmdir -v build

build/:
	mkdir build
