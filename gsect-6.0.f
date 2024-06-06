C   *********************** GSECT.F ***************
C
C   GOLDEN SECTION SEARCH ROUTINE
C
C   SEARCHES FOR A MINIMUM OF F, OVER INTERVAL XMIN -> XMAX, WITH
C   PRECISION EP. ON OUTPUT, OPTIMUM VALUE OF X IS (XMIN+XMAX)/2.
C
C   VERSION 6.0
C
      SUBROUTINE GSECT(F,XMIN,XMAX,EP)
      DATA GS/0.3819660/
      IF (XMAX.EQ.XMIN) RETURN
      IF (EP.EQ.0.) RETURN
      IF (XMAX.LT.XMIN) THEN
         TEMP=XMAX
         XMAX=XMIN
         XMIN=TEMP
         END IF
      DELX=XMAX-XMIN
      XA=XMIN+DELX*GS
      FA=F(XA)
      XB=XMAX-DELX*GS
      FB=F(XB)
 100  DELXSAV=DELX
      IF (DELX.LT.EP) RETURN
      IF (FB.LT.FA) GO TO 200
      XMAX=XB
      DELX=XMAX-XMIN
      IF (DELX.EQ.DELXSAV) RETURN
      XB=XA
      FB=FA
      XA=XMIN+DELX*GS
      FA=F(XA)
      GO TO 100
 200  XMIN=XA
      DELX=XMAX-XMIN
      IF (DELX.EQ.DELXSAV) RETURN
      XA=XB
      FA=FB
      XB=XMAX-DELX*GS
      FB=F(XB)
      GO TO 100
      END
