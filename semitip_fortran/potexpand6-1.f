C   ******************** POTEXPAND ************************
C
C   EXPAND THE GRID OF Z VALUES AND CORRESPONDING POTENTIALS IN THE 
C   VACUUM AND THE SEMICONDUCTOR, INTO SOMETHING WITH APPROXIMATELY 
C   EQUAL Z SPACING SUITABLE FOR USE IN INTEGRATING THE SCHRODINGER EQN
C
C   VERSION 1.0 - FEB/11, SAME AS PRIOR UNNUMBERED VERSIONS OF POTCUT2
C           6.0 - FEB/11, NEXSEM(1) NOW REFERS TO FIRST POINT IN SEMICONDUCTOR
C                         (NOT TO POINT ON SURFACE)
C           6.1 - MAY/13, INCLUDE IMAGE POTENTIAL
C
C   INPUT/OUTPUT PARAMETERS:
C      IMPOT=INDICATOR FOR IMAGE POTENTIAL (0=DON'T INCLUDE IT, 1=INCLUDE IT)
C      SEP=SEPARATION BETWEEN SEMICONDUCTOR AND END OF TIP (NM)
C      NV=NUMBER OF VALUES IN VAC ARRAY
C      Pot0p=SEMICONDUCTOR POTENTIAL ENERGY AT SURFACE ON CENTRAL AXIS
C      S=ARRAY OF Z VALUES IN SEMICONDUCTOR
C      NS=NUMBER OF VALUES IN SEM ARRAY
C      NSDIM=Z-DIMENSION FOR SEM ARRAY
C      BARR=POTENTIAL VALUES ON SURFACE AND IN VACUUM
C      NBARR1=NUMBER OF VALUES IN BARR ARRAY
C      BARR2=EXPANDED VALUES FOR POTENTIAL ON SURFACE AND IN VACUUM
C      NBARR2=NUMBER OF VALUES IN BARR2 ARRAY
C      NVDIM1=DIMENSION OF BARR ARRAY
C      NVDIM2=DIMENSION OF BARR2 ARRAY
C      PROF=POTENTIAL VALUES IN SEMICONDUCTOR
C      PROF2=EXPANDED VALUES FOR POTENTIAL IN SEMICONDUCTOR
C      NSDIM2=DIMENSION OF S2, PROF2, AND JSEM ARRAYS
C      S2=ARRAY OF Z VALUES IN EXPANDED ARRAY
C      NS2=NUMBER OF S2 VALUES
C      VACSTEP=TARGET SIZE FOR DELZ VALUES IN VACUUM
C      SEMSTEP=TARGET SIZE FOR DELZ VALUES IN SEMICONDUCTOR
C      FRAC=FRACTION OF NS VALUES USED IN INTEGRATION OF SCHRODINGER EQN 
C      JSEM=ARRAY OF CORRESPONDING J VALUES FOR EACH J' VALUE
C         (J LABELS Z VALUES IN S ARRAY, AND J' LABELS THOSE IN S2)
C      NEXSEM=ARRAY OF EXPANSION VALUES IN SEMICONDUCTOR (THIS GIVES THE
C         EXPANDED NUMBER OF POINTS, SO NUMBER OF INTERVALS IS 1 + THAT)
C      NEXVAC=EXPANSION VALUE IN VACUUM
C      IWRIT=OUTPUT PARAMETER
C
      SUBROUTINE POTEXPAND(IMPOT,SEP,NV,Pot0p,S,NS,NSDIM,BARR,NBARR1,
     &BARR2,NBARR2,NVDIM1,NVDIM2,PROF,PROF2,NSDIM2,S2,NS2,VACSTEP,
     &SEMSTEP,JSEM,NEXSEM,NEXVAC,IWRIT)
C
      DIMENSION S(NSDIM),BARR(NVDIM1),BARR2(NVDIM2),PROF(NSDIM),
     &PROF2(NSDIM2),S2(NSDIM2),JSEM(NSDIM2),NEXSEM(NSDIM)
      real kappa,lambda
      COMMON/SEMI/EGAP,ED,EA,ACB,AVB,CD,CA,EPSIL,TK,IDEG,IINV
C
C   EXPAND VACUUM BARRIER
C
      nexpan=MAX0(1,NINT((SEP/NV)/VACSTEP))
      IF (IMPOT.EQ.1) NEXPAN=NEXPAN*10
      NEXVAC=NEXPAN
      IF (IWRIT.GT.1) THEN
         write(6,*) 'expansion factor for barrier =',nexpan
         write(16,*)'expansion factor for barrier =',nexpan
      END IF
      NBARR2=nexpan*(NBARR1-1)+1
      BARR2(NBARR2)=BARR(NBARR1)
      DO 150 J=NBARR1-1,1,-1
         B2=BARR(J+1)
         B1=BARR(J)
         DO 140 K=nexpan-1,0,-1
            BARR2((J-1)*nexpan+K+1)=
     &               (B2*FLOAT(K)+B1*FLOAT(nexpan-K))/nexpan
140      CONTINUE
150   CONTINUE
      IF (IWRIT.GE.3) THEN
         DO 160 I=1,NBARR2
            WRITE(71,*) -(I-1)*SEP/float(NBARR2-1),BARR2(I)
160      CONTINUE
      END IF
      IF (IWRIT.GT.1) THEN
         WRITE(6,*) 'number of expanded points in vacuum =',NBARR2
         WRITE(16,*)'number of expanded points in vacuum =',NBARR2
      END IF
      lambda=3.81**2*0.1*alog(2.)/(2.*2.*sep)
      IF (IMPOT.EQ.1) THEN
      do 200 j=2,NBARR2-1
         barr2(j)=barr2(j)-1.15*lambda*(NBARR2-1.)**2/
     &            ((j-1.)*(float(NBARR2)-j))
200   continue
      END IF
      IF (IWRIT.GE.3) THEN
         DO 260 I=1,NBARR2
            WRITE(72,*) -(I-1)*SEP/float(NBARR2-1),BARR2(I)
260      CONTINUE
      END IF
c
c   EXPAND THE POTENTIAL PROFILE IN SEMICONDUCTOR
c
      DO 300 J=1,NS
         NEXSEM(J)=0
300   CONTINUE
      NEXPAN=max0(1,NINT(2.*S(1)/SEMSTEP))
      IF (IWRIT.GT.1) THEN
       write(6,*) 'initial expansion factor for semiconductor =',nexpan
       write(16,*)'initial expansion factor for semiconductor =',nexpan
      END IF
      KK=0
      DO 570 J=1,NS
         IF (J.EQ.1) THEN
            NEXPAN=MAX0(1,NINT(S(1)/SEMSTEP))
         ELSE
            NEXPAN=MAX0(1,NINT((S(J)-S(J-1))/SEMSTEP))
         END IF
         IF (MOD(NEXPAN,2).EQ.0) NEXPAN=NEXPAN+1
         DO 560 K=1,NEXPAN
            KK=KK+1
            IF (J.EQ.1) THEN
               JSEM(KK)=J
            ELSE
               IF (K.LE.(NEXPAN/2)) THEN
                  JSEM(KK)=J-1
               ELSE
                  JSEM(KK)=J
               END IF
            END IF
            NEXSEM(JSEM(KK))=NEXSEM(JSEM(KK))+1
            IF (KK.GT.NSDIM2) THEN
               WRITE(6,*) '*** ERROR - NSDIM2 TOO SMALL ',KK,NSDIM2
               WRITE(16,*)'*** ERROR - NSDIM2 TOO SMALL ',KK,NSDIM2
               WRITE(6,*) 'PRESS THE ENTER KEY TO EXIT'
               WRITE(16,*)'PRESS THE ENTER KEY TO EXIT'
               READ(5,*)
               STOP
            END IF
            IF (J.EQ.1) THEN
               PROF2(KK)=((NEXPAN-K)*Pot0p+(K)*PROF(J))/FLOAT(NEXPAN)
            ELSE
               PROF2(KK)=((NEXPAN-K)*PROF(J-1)+(K)*PROF(J))
     &                                                /FLOAT(NEXPAN)
               END IF
            IF (J.EQ.1) THEN
               S2(KK)=((NEXPAN-K)*0.+(K)*S(J))/FLOAT(NEXPAN)
            ELSE
               S2(KK)=((NEXPAN-K)*S(J-1)+(K)*S(J))/FLOAT(NEXPAN)
            END IF
560      CONTINUE
570   CONTINUE
      NS2=KK
      IF (IWRIT.GT.1) THEN
         WRITE(6,*) 'number of expanded points in semiconductor =',NS2
         WRITE(16,*)'number of expanded points in semiconductor =',NS2
      END IF
      RETURN
      END
