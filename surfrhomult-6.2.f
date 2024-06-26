C   ************** SURFRHOMULT.F ****************
C
C   CHARGE DENSITIES FOR SURFACE OF AN INHOMOGENEOUS SEMICONDUCTOR
C
C   VERSION 6.0 - FEB/11, DERIVED FROM surfrho-6.0
C           6.1 - JUN/11, RELABEL E, EF IN SIG
C           6.2 - OCT/15, FIX NUMEROUS BUGS ENCOUNTERED WHEN USING TWO NONZERO SURFACE CHARGE DENSITIES
C
C   CONSTRUCT TABLE OF SURFACE CHARGE DENSITY VALUES
C
      SUBROUTINE SURFRHO(IAR,DELE,ESTART,NE,NEDIM,RHOSTAB)
      PARAMETER(NARDIM=2)
      DIMENSION RHOSTAB(NARDIM,NEDIM)
      DOUBLE PRECISION SUM
      REAL*8 SIG,SIGSUM
      COMMON/SURF/ISTK,TK,EN0(NARDIM),EN(NARDIM,2),DENS(NARDIM,2),
     &FWHM(NARDIM,2),ECENT(NARDIM,2)
C
      IF (NE.GT.NEDIM) THEN
         WRITE(6,*) '*** ERROR - NE > NEDIM; PROGRAM HALTED'
         WRITE(6,*) 'TYPE ENTER TO CONTINUE'
         READ(5,*)
         STOP
      END IF
      IF (ISTK.EQ.1) THEN
         DO 200 I=1,NE
            EF1=(I-1)*DELE+ESTART
            IF (DENS(IAR,2).EQ.0.) THEN
               RHOSTAB(IAR,I)=RHOS1(IAR,EF1,DELE)
            ELSE IF (DENS(IAR,1).EQ.0.) THEN
               RHOSTAB(IAR,I)=RHOS2(IAR,EF1,DELE)
            ELSE
               RHOSTAB(IAR,I)=RHOS(IAR,EF1,DELE)
            END IF
200      CONTINUE
      ELSE
         IF (DENS(IAR,1).EQ.0.OR.DENS(IAR,2).EQ.0.) THEN
            NEN=NINT((EN0(IAR)-ESTART)/DELE)+1
            RHOSTAB(IAR,NEN)=0.
            SUM=0.
            DO 300 I=NEN+1,NE
               EF1=(I-1)*DELE+ESTART
               SUM=SUM+SIGSUM(IAR,EF1)
               RHOSTAB(IAR,I)=SUM*DELE
300         CONTINUE
            SUM=0.
            DO 310 I=NEN-1,1,-1
               EF1=(I-1)*DELE+ESTART
               SUM=SUM+SIGSUM(IAR,EF1)
               RHOSTAB(IAR,I)=SUM*DELE
310         CONTINUE
         ELSE
            NEN=NINT((EN0(IAR)-ESTART)/DELE)+1
            RHOSTAB(IAR,NEN)=0.
            DO 400 I=NEN+1,NE
               EF1=(I-1)*DELE+ESTART
               RHOSTAB(IAR,I)=RHOS(IAR,EF1,DELE)
400         CONTINUE
            DO 410 I=NEN-1,1,-1
               EF1=(I-1)*DELE+ESTART
               RHOSTAB(IAR,I)=RHOS(IAR,EF1,DELE)
410         CONTINUE
         END IF
      END IF
      RETURN
      END
C
C   TOTAL INTEGRATED DENSITY OF SURFACE CHARGE
C
      FUNCTION RHOS(IAR,EF1,DELE)
C
      RHOS=RHOS1(IAR,EF1,DELE)+RHOS2(IAR,EF1,DELE)
      RETURN
      END
C
C   INTEGRATED DENSITY OF SURFACE CHARGE 1
C
      FUNCTION RHOS1(IAR,EF1,DELE)
      PARAMETER(NARDIM=2)
      DOUBLE PRECISION SUM
      REAL*8 SIG,SIGSUM
      COMMON/SURF/ISTK,TK,EN0(NARDIM),EN(NARDIM,2),DENS(NARDIM,2),
     &FWHM(NARDIM,2),ECENT(NARDIM,2)
C
      SUM=0.
      E=EN(IAR,1)
      IF (EF1.EQ.EN(IAR,1)) GO TO 900
      IF (ISTK.EQ.0) GO TO 300
*
*   FULL TEMPERATURE DEPENDENCE
*
      IF (EF1.LT.EN(IAR,1)) GO TO 200
100   E=E+DELE
      IF (E.GT.(EF1+10.*TK)) GO TO 900
      SUM=SUM+SIG(IAR,1,E)*fd(e,ef1,tk)*DELE
      GO TO 100
200   E=E-DELE
      IF (E.LT.(EF1-10.*TK)) GO TO 900
      SUM=SUM+SIG(IAR,1,E)*(1.-fd(e,ef1,tk))*DELE
      GO TO 200
*
*   T=0 APPROXIMATION
*
300   IF (EF1.LT.EN(IAR,1)) GO TO 500
400   E=E+DELE
      IF (E.GT.EF1) GO TO 900
      SUM=SUM+SIG(IAR,1,E)*DELE
      GO TO 400
500   E=E-DELE
      IF (E.LT.EF1) GO TO 900
      SUM=SUM+SIG(IAR,1,E)*DELE
      GO TO 500
900   RHOS1=SUM
      RETURN
      END
C
C   INTEGRATED DENSITY OF SURFACE CHARGE 2
C
      FUNCTION RHOS2(IAR,EF1,DELE)
      PARAMETER(NARDIM=2)
      DOUBLE PRECISION SUM
      REAL*8 SIG,SIGSUM
      COMMON/SURF/ISTK,TK,EN0(NARDIM),EN(NARDIM,2),DENS(NARDIM,2),
     &FWHM(NARDIM,2),ECENT(NARDIM,2)
C
      SUM=0.
      E=EN(IAR,2)
      IF (EF1.EQ.EN(IAR,2)) GO TO 900
      IF (ISTK.EQ.0) GO TO 300
*
*   FULL TEMPERATURE DEPENDENCE
*
      IF (EF1.LT.EN(IAR,2)) GO TO 200
100   E=E+DELE
      IF (E.GT.(EF1+10.*TK)) GO TO 900
      SUM=SUM+SIG(IAR,2,E)*fd(e,ef1,tk)*DELE
      GO TO 100
200   E=E-DELE
      IF (E.LT.(EF1-10.*TK)) GO TO 900
      SUM=SUM+SIG(IAR,2,E)*(1.-fd(e,ef1,tk))*DELE
      GO TO 200
*
*   T=0 APPROXIMATION
*
300   IF (EF1.LT.EN(IAR,2)) GO TO 500
400   E=E+DELE
      IF (E.GT.EF1) GO TO 900
      SUM=SUM+SIG(IAR,2,E)*DELE
      GO TO 400
500   E=E-DELE
      IF (E.LT.EF1) GO TO 900
      SUM=SUM+SIG(IAR,2,E)*DELE
      GO TO 500
900   RHOS2=SUM
      RETURN
      END
C
      REAL*8 FUNCTION SIGSUM(IAR,ENER)
      REAL*8 SIG
      SIGSUM=SIG(IAR,1,ENER)+SIG(IAR,2,ENER)
      RETURN
      END
C
C   FIND CHARGE NEUTRALITY LEVEL
C
      SUBROUTINE ENFIND(IAR,EN1,EN2,EN0,NE)
      REAL*8 SIGTMP,SIGSUM
C
      EN0=EN1
      ESTART=EN1
C      NE=20000
      DELE=ABS(EN1-EN2)/FLOAT(NE)
      IF (DELE.EQ.0.) RETURN
      IF (EN2.LT.EN1) DELE=-DELE
      DO 100 IE=0,NE
         EF1=ESTART+IE*DELE
         SIGTMP=RHOS(IAR,EF1,ABS(DELE))
         IF (DELE.GT.0.) THEN
            IF (SIGTMP.LE.0.D0) GO TO 200
         ELSE
            IF (SIGTMP.GE.0.D0) GO TO 200
         END IF
100   CONTINUE
200   EN0=EF1
      RETURN
      END
      