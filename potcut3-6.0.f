C   ******************** POTCUT3 ************************
C
C   MAKE A CUT OF THE POTENTIAL ALONG A GIVEN LATERAL POSITION STARTING
C   FROM 3D GRID, BY INTERPOLATING BETWEEN SURROUNDING GRID POINTS
C
C   ICUT=0, INTERPOLATE POTENTIAL AT CENTRAL AXIS
C   ICUT=1, CUT AT FIRST RADIAL POINT, ETC.
C
C   VERSION 6.0 - FEB/11 - DEVELOPED FROM POTCUT2 VERSION 1.0
C
C   INPUT PARAMETERS:
C      VAC,SEM,VSINT ARRAYS, TOGETHER WITH S,DELS, ETC.
C
C   OUTPUT PARAMETERS:
C      BARR=POTENTIAL VALUES THROUGH VACUUM AND INCLUDING SURFACE
C      PROF=POTENTIAL VALUES THROUGH SEMICONDUCTOR
C      NBARR1=NUMBER OF POINTS IN VACUUM BARRIER, PLUS ONE FOR SURFACE
C
C   CALLS PCENT (FROM SEMITIP3 FILE) TO OBTAIN POTENTIAL ON CENTRAL AXIS
C
      SUBROUTINE POTCUT3(ICUT,VAC,TIP,SEM,VSINT,NRDIM,NVDIM,NSDIM,NPDIM,
     &   NV,NS,NP,SEP,S,DELV,Pot0,BIAS,CHI,CPot,EGAP,BARR,PROF,NBARR1,
     &   NVDIM1,NVDIM2,IWRIT)
C
      DIMENSION VAC(2,NRDIM,NVDIM,NPDIM),SEM(2,NRDIM,NSDIM,NPDIM),
     &VSINT(2,NRDIM,NPDIM),S(NSDIM),BARR(NVDIM1),PROF(NSDIM),DELV(NRDIM)
      LOGICAL TIP(NRDIM,NVDIM,NPDIM)
      real kappa,lambda
C
C   CONSTRUCT VACUUM BARRIER (FIRST POINT IS THE SURFACE)
C
      IF (ICUT.EQ.0) THEN
         Pot0=PCENT(0,VAC,SEM,VSINT,NRDIM,NVDIM,NSDIM,NPDIM,NP)
      ELSE
         Pot0=VSINT(1,ICUT,1)
      END IF
      NBARR1=0
      BARR(1)=chi+egap+Pot0
      DO 100 J=1,NV
         IF (TIP(1,J,1)) GO TO 110
         IF (ICUT.EQ.0) THEN
            BARR(J+1)=chi+egap+PCENT(J,VAC,SEM,VSINT,NRDIM,NVDIM,
     &                               NSDIM,NPDIM,NP)
         ELSE
            Z=SEP*J/FLOAT(NV)
            JP=Z/DELV(ICUT)
            F=(Z-JP*DELV(ICUT))/DELV(ICUT)
            IF (JP.EQ.0) THEN
            BARR(J+1)=chi+egap+VSINT(1,ICUT,1)*(1.-F)+
     &                                           VAC(1,ICUT,JP+1,1)*F
            ELSE
            BARR(J+1)=chi+egap+VAC(1,ICUT,JP,1)*(1.-F)+
     &                                           VAC(1,ICUT,JP+1,1)*F
            END IF
         END IF
100   CONTINUE
110   BARR(J+1)=chi+egap+(BIAS+CPot)
      NBARR1=J+1
c
c   CONSTRUCT POTENTIAL PROFILE IN SEMICONDUCTOR
c
      DO 500 J=1,NS
         IF (ICUT.EQ.0) THEN
            PROF(J)=PCENT(-J,VAC,SEM,VSINT,NRDIM,NVDIM,NSDIM,NPDIM,NP)
         ELSE
            PROF(J)=SEM(1,ICUT,J,1)
         END IF
500   CONTINUE
      RETURN
      END
