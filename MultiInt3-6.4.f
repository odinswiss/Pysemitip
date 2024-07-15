C   ******************** MultInt3 ************************
C
C   CALLING PROGRAM FOR E-FIELD AND TUNNEL CURRENT COMPUTATIONS FOR A 
C   SEMICONDUCTOR WITH MULTIPLE REGIONS OF BULK CHARGE OR AREAS OF 
C   SURFACE CHARGE, IN 3D. CURRENT COMPUTED USING INTEGRATION OF 
C   SCHRODINGER EQUATION ALONG CENTRAL AXIS.
C
C   VERSION 6.1 - FEB/11, DERIVED FROM UniInt3_1.1
C           6.2 - JUN/11, RELABEL E, EF IN SIG
C           6.3 - DEC/12, INTRODUCE PARAMETERS FOR TIP POSITION
C           6.4 - OCT/15, INCLUDE OUTPUT OF SURFACE CHARGE DENSITIES; PASS NE TO ENFIND
C
C   CALLS SEMITIP3 VERSION 6.1 FOR SOLVING POISSON'S EQN (ROUTINES
C   RHOSURF AND RHOBULK BELOW ARE CALLED BY SEMITIP3 TO SUPPLY CHARGE DENSITIES).
C
C   CALLS SEMIRHOMULT VERSION 6.0 FOR EVALUATING BULK CHARGE DENSITIES.
C
C   CALLS SURFRHOMULT VERSION 6.1 FOR EVALUATING SURFACE CHARGE DENSITIES.
C
C   CALLS POTCUT3 VERSION 6.0 FOR OBTAINING POTENTIAL PROFILES.
C
C   CALLS INTCURR VERSION 6.1 FOR SOLVING SCHRODINGER'S EQN.
C
C   PARAMETER STATEMENT BELOW, AS WELL AS /CD/ COMMON BLOCK, MUST BE
C   DUPLICATED IN ROUTINES RHOSURF AND RHOBULK, LOCATED AT BOTTOM OF FILE
C
      PARAMETER(NRDIM=512,NVDIM=64,NSDIM=512,NPDIM=64,NVDIM1=NVDIM+1,
     &NVDIM2=2048,NSDIM2=20000,NEDIM=50000,NREGDIM=2,NARDIM=2)
C      
      DIMENSION VAC(2,NRDIM,NVDIM,NPDIM),SEM(2,NRDIM,NSDIM,NPDIM),
     &VSINT(2,NRDIM,NPDIM),R(NRDIM),S(NSDIM),DELV(NRDIM),ITMAX(10),
     &EP(10),BBIAS(1000),NLOC(4),BARR(NVDIM1),PROF(NSDIM),AVBL(NREGDIM),
     &AVBH(NREGDIM),AVBSO(NREGDIM),ESO(NREGDIM)
      LOGICAL TIP(NRDIM,NVDIM,NPDIM)
      CHARACTER*1 ANS
C
C   /SEMI/ COMMON BLOCK USED BY SEMIRHOMULT ROUTINES
C
C      TK=TEMPERATURE
C      EGAP=BAND GAP
C      ED=DONOR BINDING ENERGY
C      EA=ACCEPTOR BINDING ENERGY
C      ACB=CONDUCTION BAND EFFECTIVE MASS
C      AVB=AVERAGED VALENCE BAND EFFECTIVE MASS
C      CD=CONCENTRATION OF DONORS
C      CA=CONCENTRATION OF ACCEPTORS
C      IDEG=INDICATOR OF WHETHER DEGENERACY APPLIES
C      IINV=INDICATOR OF WHETHER INVERSION IS ALLOWED
C      DELVB=VALENCE BAND OFFSET
C
      COMMON/SEMI/TK,EGAP(NREGDIM),ED(NREGDIM),EA(NREGDIM),ACB(NREGDIM),
     &AVB(NREGDIM),CD(NREGDIM),CA(NREGDIM),IDEG(NREGDIM),IINV(NREGDIM),
     &DELVB(NREGDIM)
C
C   /PROTRU/ COMMON BLOCK USED BY ROUTINE P, BELOW 
C
C      RAD2=RADIUS OF HEMISPHERICAL PROTRUSION
C
      COMMON/PROTRU/RAD2
C
C   /SURF/ COMMON BLOCK USED BY SURFRHOMULT ROUTINES
C
C      ISTK=INDICATOR FOR TEMPERATURE DEPENDENCE OF SURFACE CHARGE
C      TK1=TEMPERATURE (=TK)
C      EN0=COMBINED CHARGE NEUTRALITY LEVEL
C      EN=SEPARATE CHARGE NEUTRALITY LEVELS
C      DENS=DENSITY FOR SURFACE STATE DISTRIBUTIONS
C      FWHM=WIDTH OF GAUSSIAN DISTRIBUTIONS
C      ECENT=CENTROID ENERGY FOR GAUSSIAN DISTRIBUTIONS
C
      COMMON/SURF/ISTK,TK1,EN0(NARDIM),EN(NARDIM,2),DENS(NARDIM,2),
     &FWHM(NARDIM,2),ECENT(NARDIM,2)
C
C   /CD/ COMMON BLOCK USED BY RHOSURFMULT AND RHOBULKMULT, BELOW
C
C      EF=FERMI-LEVEL POSITION
C      ESTART=STARTING ENERGY IN CHARGE DENSITY TABLES
C      DELE=ENERGY STEP SIZE IN TABLES
C      NE=NUMBER OF POINTS IN TABLES
C      RHOBTAB=TABLE OF BULK TOTAL CHARGE DENSITY
C      RHOSTAB=TABLE OF SURFACE CHARGE DENSITY
C
      COMMON/CD/EF,ESTART,DELE,NE,RHOBTAB(NREGDIM,NEDIM),
     &RHOSTAB(NARDIM,NEDIM)
C
C   /TIPPOS/ COMMON BLOCK USED BY IGETREG AND IGETAR, BELOW
C
      COMMON/TIPPOS/X0,Y0
C
      DATA EPSIL0/8.854185E-12/E/1.60210E-19/
      PI=4.*ATAN(1.)
C
C   SEMICONDUCTOR AND TIP PARAMETERS
C
      READ(9,*) NPARM
      DO 900 IPARM=1,NPARM
      READ(9,*) SLOPE
      THETA=360.*ATAN(1./SLOPE)/PI
      READ(9,*) SEPIN
      READ(9,*) RAD
      READ(9,*) RAD2
      READ(9,*) CPot
      WRITE(6,*) ' '
      WRITE(16,*) ' '
      WRITE(6,*) 'RAD, SLOPE, ANGLE =',RAD,SLOPE,THETA 
      WRITE(16,*) 'RAD, SLOPE, ANGLE =',RAD,SLOPE,THETA
      WRITE(6,*) 'CONTACT POTENTIAL =',CPot
      WRITE(16,*) 'CONTACT POTENTIAL =',CPot
      READ(9,*) X0
      READ(9,*) Y0
      WRITE(6,*) 'POSITION OF TIP =',X0,Y0
      WRITE(16,*) 'POSITION OF TIP =',X0,Y0
      READ(9,*) NREG
      WRITE(6,*) 'NUMBER OF DIFFERENT REGIONS OF SEMICONDUCTOR =',NREG
      IF (NREG.GT.NREGDIM) THEN
         WRITE(6,*) 'INPUT NUMBER OF REGIONS > NUMBER OF REGIONS IN ',
     &      'PARAMETER STATEMENT'
         WRITE(6,*) 'PROGRAM WILL BE EXITED (TYPE RETURN)'
         READ(5,*)
         STOP
      END IF
      DO 40 IREG=1,NREG
         IF (NREG.GT.1) THEN
            WRITE(6,*) 'REGION #',IREG
            WRITE(16,*) 'REGION #',IREG
         END IF
         READ(9,*) CD(IREG)
         READ(9,*) CA(IREG)
         WRITE(6,*) 'DOPING =',CD(IREG),CA(IREG)
         WRITE(16,*) 'DOPING =',CD(IREG),CA(IREG)
         READ(9,*) EGAP(IREG)
         READ(9,*) DELVB(IREG)
         WRITE(6,*) 'BAND GAP, VB OFFSET =',EGAP(IREG),DELVB(IREG)
         WRITE(16,*) 'BAND GAP, VB OFFSET =',EGAP(IREG),DELVB(IREG)
         READ(9,*) ED(IREG)
         READ(9,*) EA(IREG)
         READ(9,*) ACB(IREG)
         read(9,*) AVBH(IREG)
         read(9,*) AVBL(IREG)
         AVB(IREG)=exp(2.*alog(sqrt(AVBH(IREG)**3)+
     &                         sqrt(AVBL(IREG)**3))/3.)
         read(9,*) AVBSO(IREG)
         read(9,*) ESO(IREG)
C   PARAMETERS BELOW ELIMINATED FROM VERSION 4.1/5.1 AND BEYOND      
C      read(9,*) E2HH
C      read(9,*) E2SO
         READ(9,*) IDEG(IREG)
         READ(9,*) IINV(IREG)
         IF ((CA(IREG).GT.CD(IREG).AND.
     &         (IINV(IREG).EQ.1.OR.IINV(IREG).EQ.3)).OR.
     &         (CD(IREG).GT.CA(IREG).AND.
     &         (IINV(IREG).EQ.2.OR.IINV(IREG).EQ.3))) THEN
            WRITE(6,*) '****** WARNING - LIKELY INCOMPATIBLE DOPING ',
     &         'AND INVERSION (IINV) PARAMETER'
            WRITE(6,*) 'CONTINUE (y/n) ?'
            READ(5,30) ANS
30          FORMAT(1A1)         
            IF (ANS.NE.'y'.AND.ANS.NE.'Y') STOP
         END IF
40    CONTINUE         
      READ(9,*) EPSIL
      READ(9,*) TEM
      TK=TEM*8.617E-5
      TK1=TK
      READ(9,*) NAR
      WRITE(6,*) 'NUMBER OF DIFFERENT AREAS OF SURFACE STATES =',NAR
      IF (NAR.GT.NARDIM) THEN
         WRITE(6,*) 'INPUT NUMBER OF AREAS > NUMBER OF AREAS IN ',
     &      'PARAMETER STATEMENT'
         WRITE(6,*) 'PROGRAM WILL BE EXITED (TYPE RETURN)'
         READ(5,*)
         STOP
      END IF
      DO 50 IAR=1,NAR
         IF (NAR.GT.1) THEN
            WRITE(6,*) 'AREA #',IAR
            WRITE(16,*) 'AREA #',IAR
         END IF
         READ(9,*) DENS(IAR,1)
         READ(9,*) EN(IAR,1)
         READ(9,*) FWHM(IAR,1)
         READ(9,*) ECENT(IAR,1)
         READ(9,*) DENS(IAR,2)
         READ(9,*) EN(IAR,2)
         READ(9,*) FWHM(IAR,2)
         READ(9,*) ECENT(IAR,2)
         WRITE(6,*) 'FIRST DISTRIBUTION OF SURFACE STATES:'
         WRITE(16,*) 'FIRST DISTRIBUTION OF SURFACE STATES:'
         WRITE(6,*) 'SURFACE STATE DENSITY, EN =',DENS(IAR,1),EN(IAR,1)
         WRITE(16,*) 'SURFACE STATE DENSITY, EN =',DENS(IAR,1),EN(IAR,1)
         WRITE(6,*) 'FWHM, ECENT =',FWHM(IAR,1),ECENT(IAR,1)
         WRITE(16,*) 'FWHM, ECENT =',FWHM(IAR,1),ECENT(IAR,1)
         WRITE(6,*) 'SECOND DISTRIBUTION OF SURFACE STATES:'
         WRITE(16,*) 'SECOND DISTRIBUTION OF SURFACE STATES:'
         WRITE(6,*) 'SURFACE STATE DENSITY, EN =',DENS(IAR,2),EN(IAR,2)
         WRITE(16,*) 'SURFACE STATE DENSITY, EN =',DENS(IAR,2),EN(IAR,2)
         WRITE(6,*) 'FWHM, ECENT =',FWHM(IAR,2),ECENT(IAR,2)
         WRITE(16,*) 'FWHM, ECENT =',FWHM(IAR,2),ECENT(IAR,2)
50    CONTINUE
      READ(9,*) ISTK
C
C   GRID SIZES, STEP SIZES, AND ITERATION LIMITS
C
      READ(9,*) MIRROR
      IF (MIRROR.EQ.1) THEN
         WRITE(6,*) 'HORIZONTAL MIRROR PLANE ASSUMED'
         WRITE(16,*) 'HORIZONTAL MIRROR PLANE ASSUMED'
         IF (Y0.NE.0.) THEN
            WRITE(6,*) '*** WARNING - Y0 <> 0 WITH MIRROR PLANE;',
     &                 ' WILL SET Y0 TO ZERO'
            WRITE(16,*) '*** WARNING - Y0 <> 0 WITH MIRROR PLANE;',
     &                 ' WILL SET Y0 TO ZERO'
            Y0=0.
         END IF
      END IF
      READ(9,*) NRIN
      READ(9,*) NVIN
      READ(9,*) NSIN
      READ(9,*) NPIN
      READ(9,*) SIZE
      IF (SIZE.LE.0.) THEN
         READ(9,*) DELRIN
         READ(9,*) DELSIN
      END IF
      READ(9,*) IPMAX
      READ(9,*) (ITMAX(IP),IP=1,IPMAX)
      READ(9,*) (EP(IP),IP=1,IPMAX)
      READ(9,*) NE
C
C   FIND OVERALL CHARGE NEUTRALITY LEVEL, EN0
C
      DO 60 IAR=1,NAR
         IF (DENS(IAR,1).EQ.0.AND.DENS(IAR,2).EQ.0.) THEN
            EN0(IAR)=0.
         ELSE
            IF (DENS(IAR,1).EQ.0.) THEN
               EN0(IAR)=EN(IAR,2)
            ELSE
               IF (DENS(IAR,2).EQ.0.) THEN
                  EN0(IAR)=EN(IAR,1)
               ELSE
                  WRITE(6,*) 'SEARCHING FOR CHARGE NEUTRALITY LEVEL'
                  WRITE(16,*) 'SEARCHING FOR CHARGE NEUTRALITY LEVEL'
                  CALL ENFIND(IAR,EN(IAR,1),EN(IAR,2),EN0(IAR),NE)
               END IF
            END IF
         END IF
         WRITE(6,*) 'CHARGE-NEUTRALITY LEVEL =',EN0(IAR)
         WRITE(16,*) 'CHARGE-NEUTRALITY LEVEL =',EN0(IAR)
60    CONTINUE
      EN0MAX=EN0(1)
      EN0MIN=EN0(1)
      IF (NAR.GT.1) THEN
         DO 65 IAR=2,NAR
            EN0MAX=AMAX1(EN0MAX,EN0(IAR))
            EN0MIN=AMIN1(EN0MIN,EN0(IAR))
65       CONTINUE
      END IF
C
C    OUTPUT PARAMETER
C
      READ(9,*) IWRIT
C
C   VOLTAGES
C
      READ(9,*) NBIAS
      READ(9,*)(BBIAS(IBIAS),IBIAS=1,NBIAS)
C
C   PARAMETERS FOR CONTOUR PLOT
C
      READ(9,*) NUMC
      READ(9,*) DELPOT
      READ(9,*) PhiIN
C
C   PARAMETERS FOR COMPUTATION OF CURRENT
C
      READ(9,*) CHI
      READ(9,*) EFTIP
      READ(9,*) NWK
      READ(9,*) NEE
      READ(9,*) EXPANI
      READ(9,*) FRACZ
      READ(9,*) BMOD
      READ(9,*) ANEG
      READ(9,*) APOS
      READ(9,*) VSTART
      if (vstart.lt.0.) then
         dels1=abs(vstart)*aneg
      else
         dels1=abs(vstart)*apos
      end if
c   sep0 is separation at V=0
      sep0=sepin-dels1
C
C   FIND FERMI-LEVEL POSITION
C
      CALL EFFIND(1,EF)
      WRITE(6,*) 'REGION TYPE 1, FERMI-LEVEL =',EF
      WRITE(16,*) 'REGION TYPE 1, FERMI-LEVEL =',EF
      RHOCC=RHOCB(1,EF,0.)
      RHOVV=RHOVB(1,EF,0.)
      WRITE(6,*) 'CARRIER DENSITY IN CB, VB =',RHOCC,RHOVV
      WRITE(16,*)'CARRIER DENSITY IN CB, VB =',RHOCC,RHOVV
C
C   ****************** LOOP OVER BIAS VOLTAGES ****************************
C
      DO 600 IBIAS=1,NBIAS
      write(6,*) ' '
      write(16,*) ' '
      BIAS0=BBIAS(IBIAS)
      if (bias0.le.0) then
         sep=sep0+aneg*abs(bias0)
      else
         sep=sep0+apos*abs(bias0)
      end if
      write(6,*) 'SEPARATION =',sep
      write(16,*) 'SEPARATION =',sep
C
      IMODMAX=1
      IF (BMOD.EQ.0.) IMODMAX=-1
      do 550 imod=-1,IMODMAX,2
      BIASSAV=BIAS
      bias=bias0+imod*bmod*sqrt(2.)
      PotTIP=BIAS+CPot
      write(6,*) ' '
      write(16,*) ' '
      WRITE(6,*) 'BIAS, TIP POTENTIAL =',BIAS,PotTIP
      WRITE(16,*) 'BIAS, TIP POTENTIAL =',BIAS,PotTIP
C
C   1-D SOLUTION FOR BAND BENDING
C
      IF ((CD(1)-CA(1)).EQ.0.) GO TO 105
      W=1.E9*SQRT(2.*EPSIL*EPSIL0*AMAX1(1.,ABS(PotTIP))/
     &   (ABS(CD(1)-CA(1))*1.E6*E))
      WRITE(6,*) '1-D ESTIMATE OF DEPLETION WIDTH (NM) =',W
      WRITE(16,*) '1-D ESTIMATE OF DEPLETION WIDTH (NM) =',W
      GO TO 106
105   W=1.E10
C
C   CONSTRUCT TABLES OF CHARGE DENSITY VALUES
C
106   ESTART=AMIN1(EF,EF-PotTIP,EN0MIN)
      EEND=AMAX1(EF,EF-PotTIP,EN0MAX)
      ETMP=EEND-ESTART
      ESTART=ESTART-2.*ETMP
      EEND=EEND+2.*ETMP
      DELE=(EEND-ESTART)/FLOAT(NE-1)
C   PLACE ONE OF THE TABLE VALUES FOR ENERGY AT EF +/- (DELE/2)
      NETMP=NINT((EF-ESTART)/DELE)
      ESTART=EF-(NETMP-0.5)*DELE
      EEND=ESTART+(NE-1)*DELE
      WRITE(6,*) 'ESTART,EEND,NE =',ESTART,EEND,NE
      WRITE(16,*) 'ESTART,EEND,NE =',ESTART,EEND,NE
      WRITE(6,*) 'COMPUTING TABLE OF BULK CHARGE DENSITIES'
      WRITE(16,*) 'COMPUTING TABLE OF BULK CHARGE DENSITIES'
      DO 110 IREG=1,NREG
         CALL SEMIRHO(IREG,DELE,ESTART,NE,NEDIM,RHOBTAB,0,TMP,TMP)
110   CONTINUE
      WRITE(6,*) 'COMPUTING TABLE OF SURFACE CHARGE DENSITIES'
      WRITE(16,*) 'COMPUTING TABLE OF SURFACE CHARGE DENSITIES'
      DO 120 IAR=1,NAR
         IF (DENS(IAR,1).EQ.0.AND.DENS(IAR,2).EQ.0.) THEN
            DO 115 IE=1,NE
               RHOSTAB(IAR,IE)=0.
115         CONTINUE
         ELSE
            CALL SURFRHO(IAR,DELE,ESTART,NE,NEDIM,RHOSTAB)
         END IF
         IF (IWRIT.GE.3) THEN
            DO 118 IE=1,NE
               EF1=ESTART+(IE-1)*DELE
               ILUN=80+IAR
               WRITE(ILUN,*) EF1,RHOSTAB(IAR,IE)
118         CONTINUE
            CLOSE(UNIT=ILUN)
         END IF
120   CONTINUE
C
C   SEMICONDUCTOR GRID SIZE AND SPACING
C
      NR=NRIN
      NV=NVIN
      NS=NSIN
      IF (SIZE.GT.0.) THEN
         DELR=RAD
         IF (RAD2.NE.0.) DELR=AMIN1(RAD2,DELR)
         DELR=AMIN1(DELR,W/NR)*SIZE
         DELS=RAD
         IF (RAD2.NE.0.) DELS=AMIN1(RAD2,DELS)
         DELS=AMIN1(DELS,W/NS)*SIZE
      ELSE
         DELR=DELRIN
         DELS=DELSIN
      END IF
      NP=NPIN
      IF (MIRROR.EQ.1) THEN
         DELP=PI/FLOAT(NP)
      ELSE
         DELP=2.*PI/FLOAT(NP)
      END IF
C
C   SOLVE THE POTENTIAL PROBLEM
C
      IINIT=1
      IWRIT1=IWRIT
      IF (IWRIT.GT.5) IWRIT1=MOD(IWRIT,5)
      CALL SEMITIP3(SEP+RAD2,RAD,SLOPE,ETAT,A,Z0,C,VAC,TIP,SEM,VSINT,
     &   R,S,DELV,DELR,DELS,DELP,NRDIM,NVDIM,NSDIM,NPDIM,NR,NV,NS,NP,
     &   PotTIP,IWRIT1,ITMAX,EP,IPMAX,Pot0,IERR,IINIT,MIRROR,EPSIL,IBC)
      WRITE(6,130) NR,NS,NV,IERR
      WRITE(16,130) NR,NS,NV,IERR
130   FORMAT(' RETURN FROM SEMTIP2, NR,NS,NV,IERR =',4I7)
C
C   CURRENT COMPUTATION
C
      WRITE(10,230) RAD,SEP,BIAS,CPot,Pot0
230   FORMAT(' ',5G12.4)
      WRITE(6,*) ' '
      WRITE(16,*)' '
      WRITE(6,*) 'COMPUTATION OF CURRENT:'
      WRITE(16,*)'COMPUTATION OF CURRENT:'
C
C      GET A CUT FROM THE POTENTIAL
C
      CALL POTCUT3(0,VAC,TIP,SEM,VSINT,NRDIM,NVDIM,NSDIM,NPDIM,
     &   NV,NS,NP,SEP+RAD2,S,DELV,Pot0,BIAS,CHI,CPot,EGAP(1),BARR,PROF,
     &   NBARR1,NVDIM1,NVDIM2,0)
      IF (IWRIT.GE.1) THEN
         DO 305 J=NBARR1,1,-1
           WRITE(95,*) -(J-1)*DELV(1),BARR(J)
305      CONTINUE
         DO 310 J=1,NS
            WRITE(95,*) S(J),PROF(J)
310      CONTINUE
         CLOSE(95)
      END IF
C
C      DO THE COMPUTATION
C
      NSP=NINT(FRACZ*NS)
      SDEPTH=(2*NS*DELS/PI)*TAN(PI*NSP/(2.*NS))
      WRITE(6,*) '# GRID POINTS INTO SEMICONDUCTOR USED FOR INTEGRATION'
     &,' =',NSP
      WRITE(16,*)'# GRID POINTS INTO SEMICONDUCTOR USED FOR INTEGRATION'
     &,' =',NSP
      WRITE(6,*) 'DEPTH INTO SEMICONDUCTOR USED FOR INTEGRATION =',
     &SDEPTH
      WRITE(16,*)'DEPTH INTO SEMICONDUCTOR USED FOR INTEGRATION =',
     &SDEPTH
      IWRIT1=MOD(IWRIT,5)
      CALL INTCURR(BARR,PROF,NBARR1,NV,NS,NSP,NVDIM,NSDIM,
     &   S,SEP,BIAS,EF,CHI,EFTIP,CPot,EGAP,TK,AVBH(1),AVBL(1),
     &   AVBSO(1),ACB(1),ESO(1),E2HH,E2SO,nee,nwk,Pot0,NVDIM1,NVDIM2,
     &   NSDIM2,EXPANI,NLOC,CURRVE,CURRVL,CURRCE,CURRCL,CURRE,
     &   CURRL,IWRIT1,0,TMP,TMP,TMP,TMP,TMP,TMP)
C     
      IF ((IINV(1).EQ.1.OR.IINV(1).EQ.3).AND.CURRVE.GT.0.) THEN
         CURRVE=0.
         WRITE(6,*) 'VB EXTENDED INVERSION CURRENT SET TO ZERO'
         WRITE(16,*) 'VB EXTENDED INVERSION CURRENT SET TO ZERO'
      END IF
      IF ((IINV(1).EQ.1.OR.IINV(1).EQ.3).AND.CURRVL.GT.0.) THEN
         CURRVL=0.
         WRITE(6,*) 'VB LOCALIZED INVERSION CURRENT SET TO ZERO'
         WRITE(16,*) 'VB LOCALIZED INVERSION CURRENT SET TO ZERO'
      END IF
      write(6,*) 'valence band current ext,loc =',CURRVE,CURRVL
      write(16,*) 'valence band current ext,loc =',CURRVE,CURRVL
      IF ((IINV(1).EQ.2.OR.IINV(1).EQ.3).AND.CURRCE.LT.0.) THEN
         CURRCE=0.
         WRITE(6,*) 'CB EXTENDED INVERSION CURRENT SET TO ZERO'
         WRITE(16,*) 'CB EXTENDED INVERSION CURRENT SET TO ZERO'
      END IF
      IF ((IINV(1).EQ.2.OR.IINV(1).EQ.3).AND.CURRCL.LT.0.) THEN
         CURRCL=0.
         WRITE(6,*) 'CB LOCALIZED INVERSION CURRENT SET TO ZERO'
         WRITE(16,*) 'CB LOCALIZED INVERSION CURRENT SET TO ZERO'
      END IF
      write(6,*) 'conduction band current ext,loc =',CURRCE,CURRCL
      write(16,*) 'conduction band current ext,loc =',CURRCE,CURRCL
      CURR=CURRE+CURRL
      CURRV=CURRVE+CURRVL
      CURRC=CURRCE+CURRCL
C
C   OUTPUT CURRENT AND CONDUCTANCE
C
      if (imod.eq.-1) then
         CSAV=CURR
         CSAVE=CURRE
         CSAVL=CURRL
         CSAVV=CURRV
         CSAVVE=CURRVE
         CSAVVL=CURRVL
         CSAVC=CURRC
         CSAVCE=CURRCE
         CSAVCL=CURRCL
      else
         COND=(CURR-CSAV)
         CONDE=(CURRE-CSAVE)
         CONDL=(CURRL-CSAVL)
         CONDV=(CURRV-CSAVV)
         CONDVE=(CURRVE-CSAVVE)
         CONDVL=(CURRVL-CSAVVL)
         CONDC=(CURRC-CSAVC)
         CONDCE=(CURRCE-CSAVCE)
         CONDCL=(CURRCL-CSAVCL)
         COND=COND*exp(2.*10.*(sep-sep0-dels1))/(2.*bmod*sqrt(2.))
         CONDE=CONDE*exp(2.*10.*(sep-sep0-dels1))/(2.*bmod*sqrt(2.))
         CONDL=CONDL*exp(2.*10.*(sep-sep0-dels1))/(2.*bmod*sqrt(2.))
         CONDV=CONDV*exp(2.*10.*(sep-sep0-dels1))/(2.*bmod*sqrt(2.))
         CONDVE=CONDVE*exp(2.*10.*(sep-sep0-dels1))/(2.*bmod*sqrt(2.))
         CONDVL=CONDVL*exp(2.*10.*(sep-sep0-dels1))/(2.*bmod*sqrt(2.))
         CONDC=CONDC*exp(2.*10.*(sep-sep0-dels1))/(2.*bmod*sqrt(2.))
         CONDCE=CONDCE*exp(2.*10.*(sep-sep0-dels1))/(2.*bmod*sqrt(2.))
         CONDCL=CONDCL*exp(2.*10.*(sep-sep0-dels1))/(2.*bmod*sqrt(2.))
         write(15,*) bias0,COND,CONDE,CONDL
         write(93,*) bias0,CONDV,CONDVE,CONDVL
         write(94,*) bias0,CONDC,CONDCE,CONDCL
      end if
      CURR=CURR*exp(2.*10.*(sep-sep0-dels1))
      CURRE=CURRE*exp(2.*10.*(sep-sep0-dels1))
      CURRL=CURRL*exp(2.*10.*(sep-sep0-dels1))
      CURRV=CURRV*exp(2.*10.*(sep-sep0-dels1))
      CURRVE=CURRVE*exp(2.*10.*(sep-sep0-dels1))
      CURRVL=CURRVL*exp(2.*10.*(sep-sep0-dels1))
      CURRC=CURRC*exp(2.*10.*(sep-sep0-dels1))
      CURRCE=CURRCE*exp(2.*10.*(sep-sep0-dels1))
      CURRCL=CURRCL*exp(2.*10.*(sep-sep0-dels1))
      write(14,*) bias,CURR,CURRE,CURRL
      write(91,*) bias,CURRV,CURRVE,CURRVL
      write(92,*) bias,CURRC,CURRCE,CURRCL
C
C   PLOT CROSS-SECTIONAL PROFILE
C
500   IF (IWRIT.GE.1) THEN
         DO 505 J=NV,1,-1
           WRITE(11,*) -J*DELV(1),VAC(1,1,J,1),VAC(1,NR,J,1)
505      CONTINUE
         WRITE(11,*) 0.,VSINT(1,1,1),VSINT(1,NR,1)
         DO 510 J=1,NS
            WRITE(11,*) S(J),SEM(1,1,J,1),SEM(1,NR,J,1)
510      CONTINUE
C
C   PLOT SURFACE POTENTIAL AND SURFACE CHARGE DENSITY
C
         KPLOT1=NINT((PhiIN/(DELP*180./PI))+0.5)
         KPLOT1=MIN0(MAX0(1,KPLOT1),NP)
         Phi=(KPLOT1-0.5)*DELP*180./PI
         IF (MIRROR.EQ.1) THEN
            KPLOT2=NP-KPLOT1+1
         ELSE
            KPLOT2=MOD(KPLOT1+NP/2,NP)+1
         END IF
         WRITE(6,*) 'ACTUAL ANGLE OF CROSS-SECTIONAL PLOT =',Phi
         WRITE(6,*) 'CORRESPONDING TO ANGULAR GRID LINES ',KPLOT2,KPLOT1
         WRITE(16,*)'ACTUAL ANGLE OF CROSS-SECTIONAL PLOT =',Phi
         WRITE(16,*)'CORRESPONDING TO ANGULAR GRID LINES ',KPLOT2,KPLOT1
         DO 515 I=NR,1,-1
            WRITE(12,*) -R(I),VSINT(1,I,KPLOT2),SEM(1,I,NS,KPLOT2)
515      CONTINUE
         DO 520 I=1,NR
            WRITE(12,*) R(I),VSINT(1,I,KPLOT1),SEM(1,I,NS,KPLOT1)
520      CONTINUE
         CLOSE(11)
         CLOSE(12)
      END IF
C
550   continue
600   CONTINUE
C
C   PLOT CONTOURS
C
      IF (IWRIT.GE.2) THEN
         CALL CONTR3(ETA1,VAC,TIP,SEM,VSINT,R,S,DELV,NRDIM,NVDIM,NSDIM,
     &               NPDIM,NR,NV,NS,NP,NUMC,DELPOT,MIRROR,KPLOT1,KPLOT2)
      END IF
C
C   OUTPUT ENTIRE POTENTIAL
C
      IF (IWRIT.GE.3) THEN
         nrecl=40+4*nr*np*(nv+ns+1)+4*nr*2+4*ns
         open(unit=13,file='fort.13',access='direct',recl=nrecl)                                            
         write(13,rec=1) nr,nv,ns,np,sep,rad,rad2,slope,bias,epsil,
     &   (((vac(1,i,j,k),i=1,nr),j=1,nv),k=1,np),
     &   (((sem(1,i,j,k),i=1,nr),j=1,ns),k=1,np),
     &   ((vsint(1,i,k),i=1,nr),k=1,np),
     &   (r(i),i=1,nr),(s(j),j=1,ns),(delv(i),i=1,nr)
      END IF
C
 900  CONTINUE
      WRITE(6,*) 'PRESS THE ENTER KEY TO EXIT'
      WRITE(16,*) 'PRESS THE ENTER KEY TO EXIT'
      READ(5,*)
C
      stop
      end
C
C   ROUTINE DEFINING PROTRUSION ON END OF TIP
C
      real function p(r)
      common/protru/rad2
      p=0.
      if (r.lt.rad2) p=sqrt(rad2**2-r**2)
      return
      end
C
C   ROUTINE DEFINING SPECTRUM OF SURFACE STATES
C
      real*8 function sig(IAR,ID,ENER)
      PARAMETER(NRDIM=2048,NVDIM=2048,NSDIM=2048,NVDIM1=NVDIM+1,
     &NVDIM2=2048,NSDIM2=20000,NEDIM=50000,NREGDIM=2,NARDIM=2)
      COMMON/SURF/ISTK,TK,EN0(NARDIM),EN(NARDIM,2),DENS(NARDIM,2),
     &FWHM(NARDIM,2),ECENT(NARDIM,2)
      PI=4.*ATAN(1.)
c
c     sig=0.
c     if (ENER.lt.0.) return
c     if (ENER.gt.egap) return
c
      if (fwhm(IAR,ID).eq.0.) go to 200
      width=fwhm(IAR,ID)/(2.*sqrt(2.*alog(2.)))
      sig=-dexp(-1.d0*(ENER-(EN(IAR,ID)+ecent(IAR,ID)))**2/
     &        (2.*width**2))+
     &     dexp(-1.d0*(ENER-(EN(IAR,ID)-ecent(IAR,ID)))**2/
     &        (2.*width**2))
      sig=sig*dens(IAR,ID)/(SQRT(2.*pi)*width)
      return
c     
c     sig=exp(-(ENER-EN)**2/(2.*width**2))
c     sig=sig*dens/(SQRT(2.*pi)*width)
c
c     sig=exp(-ENER/width)-
c     &    exp((ENER-egap)/width)
c     sig=sig*dens/WIDTH
c
200   sig=dens(IAR,ID)
      if (ENER.gt.en(IAR,ID)) sig=-sig
      return
      end
C
C   ROUTINE DEFINING SPATIAL DISTRIBUTION OF SURFACE STATES
C
      REAL FUNCTION RHOSURF(Pot,X,Y,I,K,NR,NP)
C
      PARAMETER(NRDIM=2048,NVDIM=2048,NSDIM=2048,NVDIM1=NVDIM+1,
     &NVDIM2=2048,NSDIM2=20000,NEDIM=50000,NREGDIM=2,NARDIM=2)
      COMMON/CD/EF,ESTART,DELE,NE,RHOBTAB(NREGDIM,NEDIM),
     &RHOSTAB(NARDIM,NEDIM)
      PI=4.*ATAN(1.)
C
      ENER=EF-Pot
      IAR=IGETAR(X,Y)
      IENER=NINT((ENER-ESTART)/DELE)+1
      RHO=0.
      IF (IENER.GE.1.AND.IENER.LE.NE) THEN
         RHO=RHOSTAB(IAR,IENER)
      ELSE
         RHO=RHOS(IAR,ENER,DELE)
      END IF
C
C   ADD STATEMENT BELOW TO RESTRICT REGION OF SURFACE CHARGE
C      
C      IF (X.GT.8.AND.X.LT.12.AND.Y.GT.8.AND.Y.LT.12) RHO=-2.E13
C
      RHOSURF=RHO
      RETURN
      END
C
C   ROUTINE DEFINING SPATIAL DISTRIBUTION OF BULK STATES
C
      REAL FUNCTION RHOBULK(Pot,X,Y,S,I,J,K,NR,NS,NP)
C
      PARAMETER(NRDIM=2048,NVDIM=2048,NSDIM=2048,NVDIM1=NVDIM+1,
     &NVDIM2=2048,NSDIM2=20000,NEDIM=50000,NREGDIM=2,NARDIM=2)
      COMMON/CD/EF,ESTART,DELE,NE,RHOBTAB(NREGDIM,NEDIM),
     &RHOSTAB(NARDIM,NEDIM)
C
      ENER=EF-Pot
      IREG=IGETREG(X,Y,S)
      IENER=NINT((ENER-ESTART)/DELE)+1
      RHO=0.
      IF (IENER.GE.1.AND.IENER.LE.NE) THEN
         RHO=RHOBTAB(IREG,IENER)
      ELSE
         RHO=RHOB(IREG,ENER,0.)
      END IF
C      
C   ADD STATEMENT BELOW TO RESTRICT REGION OF BULK CHARGE
C     IF (R.LT.0.) RHO=0.
C
      RHOBULK=RHO
      RETURN
      END
C
C   ROUTINE DEFINING DIFFERENT AREAS OF SURFACE
C
      INTEGER FUNCTION IGETAR(X,Y)
      COMMON/TIPPOS/X0,Y0
C
      IGETAR=1
C      IF ((X+X0).GT.0.) IGETAR=2
      RETURN
      END
C
C   ROUTINE DEFINING DIFFERENT REGIONS OF SEMICONDUCTOR
C
      INTEGER FUNCTION IGETREG(X,Y,S)
      COMMON/TIPPOS/X0,Y0
C
      IGETREG=1
      IF ((X+X0).GT.0.) IGETREG=2
      RETURN
      END
C
C   ROUTINE DEFINING VB EDGE
C
      REAL FUNCTION VBEDGE(S)
      PARAMETER(NREGDIM=2)
      COMMON/SEMI/TK,EGAP(NREGDIM),ED(NREGDIM),EA(NREGDIM),ACB(NREGDIM),
     &AVB(NREGDIM),CD(NREGDIM),CA(NREGDIM),IDEG(NREGDIM),IINV(NREGDIM),
     &DELVB(NREGDIM)
C
      VBEDGE=DELVB(IGETREG(0.,0.,S))
      RETURN
      END
C
C   ROUTINE DEFINING CB EDGE
C
      REAL FUNCTION CBEDGE(S)
      PARAMETER(NREGDIM=2)
      COMMON/SEMI/TK,EGAP(NREGDIM),ED(NREGDIM),EA(NREGDIM),ACB(NREGDIM),
     &AVB(NREGDIM),CD(NREGDIM),CA(NREGDIM),IDEG(NREGDIM),IINV(NREGDIM),
     &DELVB(NREGDIM)
C
      CBEDGE=EGAP(IGETREG(0.,0.,S))+DELVB(IGETREG(0.,0.,S))
      RETURN
      END
