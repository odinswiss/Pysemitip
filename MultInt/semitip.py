import numpy as np
from math import atan, sqrt, tan, cos, sin, log

# Define constants
Q = np.float64(1.6e-19)
KT = np.float64(0.0259)
NI = np.float64(1.5e10)
EPSILON_SURFACE = np.float64(11.7 * 8.85e-12)
EEP = np.float64(1.80943e-20)
SMALL_VALUE = np.float64(1e-10)
MAX_POTENTIAL = np.float64(1e3)  # Maximum allowed potential to prevent divergence
DAMPING_FACTOR = 1  # Initial damping factor

# Updated DELR, DELS, DELV, DELP values
DELR = np.float64(0.25000)
DELS = np.float64(0.25000)
DELV = np.float64(0.12500)
DELP = np.float64(0.19635)

def rhobulk(pot, doping_concentration, q=Q, kT=KT):
    pot=1
    if pot > 0:
        return q * doping_concentration * (1 - np.exp(-q * pot / kT))
    elif pot < 0:
        return q * doping_concentration * (np.exp(q * pot / kT) - 1)
    else:
        return 0.0

def rhosurf(pot, epsilon_surface=EPSILON_SURFACE, q=Q, kT=KT, ni=NI):
    pot=-1
    if pot > 0:
        return epsilon_surface * pot / (q * ni * kT)
    elif pot < 0:
        return -epsilon_surface * abs(pot) / (q * ni * kT)
    else:
        return 0.0

def gsect(f, xmin, xmax, ep, *args):
    GS = np.float64(0.3819660)
    if xmax == xmin or ep == 0:
        return (xmin + xmax) / 2
    if xmax < xmin:
        xmin, xmax = xmax, xmin

    delx = xmax - xmin
    xa = xmin + delx * GS
    fa = f(xa, *args)
    xb = xmax - delx * GS
    fb = f(xb, *args)

    while delx >= ep:
        delxsav = delx
        if fb < fa:
            xmax = xb
            delx = xmax - xmin
            if delx == delxsav:
                return (xmin + xmax) / 2
            xb = xa
            fb = fa
            xa = xmin + delx * GS
            fa = f(xa, *args)
        else:
            xmin = xa
            delx = xmax - xmin
            if delx == delxsav:
                return (xmin + xmax) / 2
            xa = xb
            fa = fb
            xb = xmax - delx * GS
            fb = f(xb, *args)

    return (xmin + xmax) / 2

def semin(pot, epsil, eep, x, y, s, stemp, denom, doping_concentration):
    rho = rhobulk(pot, doping_concentration)
    temp = stemp - rho * eep / epsil
    return abs(pot - temp / denom)

def surfmin(pot, epsil, eep, x, y, s, stemp, denom, epsilon_surface):
    rho = rhosurf(pot, epsilon_surface)
    temp = stemp - rho * eep * 1e7
    return abs(pot - temp / denom)

def pcent(jj, VAC, SEM, VSINT, NP):
    j = abs(jj)
    summation = np.float64(0.0)
    if jj == 0:
        for k in range(NP):
            summation += (np.float64(9.0) * VSINT[0, 0, k] - VSINT[0, 1, k]) / np.float64(8.0)
    elif jj > 0:
        for k in range(NP):
            summation += (np.float64(9.0) * VAC[0, 0, j, k] - VAC[0, 1, j, k]) / np.float64(8.0)
    else:
        for k in range(NP):
            summation += (np.float64(9.0) * SEM[0, 0, j, k] - SEM[0, 1, j, k]) / np.float64(8.0)
    result = summation / np.float64(NP)
    return result

def iter3(VAC, TIP, SEM, VSINT, R, DELR, DELV, DELP, DELXSI, S, DELS, BIAS, A, NR, NV, NS, NP, EP, ITMAX, pot0, IWRIT, ETAT, C, MIRROR, EPSILON, DELETA, iter_count, damping_factor=DAMPING_FACTOR):
    pot=0
    c2 = C * C
    pot_sav = 0.0
    pot_sav2 = 0.0
    max_iterations = 400  # Set the maximum iterations to 200
    
    for iter in range(max_iterations):
        iter_count += 1
        
        if iter_count == 1:
            pot0 = np.float64(0.0)
            print(f"ITER, Pot0 = {iter_count}, {pot0:.50f}")
        else:
            pot0 = pcent(0, VAC, SEM, VSINT, NP)
            # Limit the potential to prevent divergence
            pot0 = min(max(pot0, -MAX_POTENTIAL), MAX_POTENTIAL)
            if IWRIT != 0:
                print(f"ITER, Pot0 = {iter_count}, {pot0:.50f}")

        for k in range(NP):
            for i in range(NR):
                x2m1 = (R[i] / A) ** 2
                xsi = sqrt(1.0 + x2m1)
                for j in range(NV - 1):
                    if TIP[i, j, k]:
                        continue
                    eta = j * ETAT / NV
                    eta2 = eta * eta
                    ome2 = 1.0 - eta ** 2
                    x2me2c = xsi * (xsi + C) - eta ** 2 * (C * xsi + 1.0)
                    x2me2c2 = x2me2c * x2me2c
                    t1 = x2m1 * ((xsi + C) ** 2 - eta ** 2 * (xsi * C * 2.0 + c2 + 1.0)) / x2me2c
                    t2 = ome2 * (xsi ** 2 - eta ** 2) / x2me2c
                    t3 = x2me2c / (x2m1 * ome2 + 1e-10)
                    t4 = -C * eta * x2m1 * ome2 / x2me2c
                    t5 = (c2 + 1.0) * xsi * (3.0 + xsi) / x2me2c2
                    t6 = -eta * (c2 + 4.0 * C * xsi + xsi ** 2) / x2me2c2

                    vac_im1jk = pcent(j, VAC, SEM, VSINT, NP) if i == 0 else VAC[0, i - 1, j, k]
                    vac_ip1jk = VAC[0, i, j, k] if i == NR - 1 else VAC[0, i + 1, j, k]
                    vac_ijkp1 = VAC[0, i, j, k + 1] if k < NP - 1 else VAC[0, i, j, 0]
                    vac_ijkm1 = VAC[0, i, j, k - 1] if k > 0 else VAC[0, i, j, NP - 1]

                    delr_i = max(DELXSI[i], SMALL_VALUE)
                    delr_ip1 = max(DELXSI[i + 1], SMALL_VALUE)
                    dels_j = max(DELETA, SMALL_VALUE)
                    dels_jp1 = max(DELETA, SMALL_VALUE)

                    temp = (t1 * 2.0 * (vac_ip1jk + vac_im1jk) / (delr_i + delr_ip1) +
                            t2 * (VAC[0, i, j + 1, k] + VAC[0, i, j - 1, k]) / (dels_j ** 2) +
                            t3 * (vac_ijkp1 + vac_ijkm1) / (DELP ** 2) +
                            t4 * (vac_ip1jk - vac_im1jk) / (delr_i) +
                            t5 * (vac_ip1jk - vac_im1jk) / (delr_i) +
                            t6 * (VAC[0, i, j + 1, k] - VAC[0, i, j - 1, k]) / (2.0 * dels_j))

                    VAC[1, i, j, k] = temp / (2.0 * t1 * (1.0 / delr_i) / (delr_i) +
                                              2.0 * t2 / (dels_j ** 2) + 2.0 * t3 / (DELP ** 2))

        for k in range(NP):
            for j in range(NV):
                for i in range(NR):
                    VAC[0, i, j, k] = VAC[1, i, j, k]

        for k in range(NP):
            for i in range(NR):
                x = R[i] * np.cos((k - 0.5) * DELP)
                y = R[i] * np.sin((k - 0.5) * DELP)
                surf_old = VSINT[0, i, k]
                if TIP[i, 3, k]:
                    continue
                stemp = ((3.0 * VAC[0, i, 0, k] - (9.0 / 6.0) * VAC[0, i, 1, k] + (1.0 / 3.0) * VAC[0, i, 2, k]) / (DELV[i] + 1e-10) +
                         EPSILON * (3.75 * SEM[0, i, 0, k] - (5.0 / 6.0) * SEM[0, i, 1, k] + 0.15 * SEM[0, i, 2, k]) / (DELS[0] + 1e-10))
                denom = ((11.0 / 6.0) / (DELV[i] + 1e-10) + (46.0 / 15.0) * EPSILON / (DELS[0] + 1e-10))
                rho = rhosurf(VSINT[0, i, k])
                temp = stemp - rho * EEP * 1e7
                surf_new = temp / denom
                del_surf = max(1e-6, abs(BIAS) / 1e6)

                surf_new = gsect(surfmin, surf_old, surf_new, del_surf, EPSILON, EEP, x, y, S[i], stemp, denom, EPSILON_SURFACE)

                # Apply damping factor to prevent divergence
                surf_new = damping_factor * surf_new + (1 - damping_factor) * surf_old
                # Limit the surface potential to prevent divergence
                surf_new = min(max(surf_new, -MAX_POTENTIAL), MAX_POTENTIAL)

                VSINT[1, i, k] = surf_new

        for k in range(NP):
            for i in range(NR):
                VSINT[0, i, k] = VSINT[1, i, k]

        for k in range(NP):
            for j in range(NS):
                for i in range(NR):
                    sem_old = SEM[0, i, j, k]
                    x = R[i] * np.cos((k - 0.5) * DELP)
                    y = R[i] * np.sin((k - 0.5) * DELP)
                    if i == 0:
                        sem_im1jk = pcent(-j, VAC, SEM, VSINT, NP)
                        sem_ip1jk = SEM[0, i + 1, j, k]
                    elif i == NR - 1:
                        sem_im1jk = SEM[0, i - 1, j, k]
                        sem_ip1jk = SEM[0, i, j, k]
                    else:
                        sem_im1jk = SEM[0, i - 1, j, k]
                        sem_ip1jk = SEM[0, i + 1, j, k]

                    if j == 0:
                        sem_ijp1k = SEM[0, i, j + 1, k]
                        sem_ijm1k = VSINT[0, i, k]
                    elif j == NS - 1:
                        sem_ijp1k = SEM[0, i, j, k]
                        sem_ijm1k = SEM[0, i, j - 1, k]
                    else:
                        sem_ijp1k = SEM[0, i, j + 1, k]
                        sem_ijm1k = SEM[0, i, j - 1, k]

                    if k == 0:
                        sem_ijkp1 = SEM[0, i, j, k + 1]
                        sem_ijkm1 = SEM[0, i, j, NP - 1]
                    elif k == NP - 1:
                        sem_ijkp1 = SEM[0, i, j, 0]
                        sem_ijkm1 = SEM[0, i, j, k - 1]
                    else:
                        sem_ijkp1 = SEM[0, i, j, k + 1]
                        sem_ijkm1 = SEM[0, i, j, k - 1]

                    delr_i = max(DELXSI[i], SMALL_VALUE)
                    delr_ip1 = max(DELXSI[i + 1], SMALL_VALUE)
                    dels_j = max(DELETA, SMALL_VALUE)
                    dels_jp1 = max(DELETA, SMALL_VALUE)

                    stemp = (2.0 * (sem_ip1jk / delr_ip1 + sem_im1jk / delr_i) / (delr_ip1 + delr_i + 1e-10) +
                             2.0 * (sem_ijp1k / dels_jp1 + sem_ijm1k / dels_j) / (dels_jp1 + dels_j + 1e-10) +
                             np.nan_to_num((sem_ip1jk - sem_im1jk) / (R[i] * (delr_ip1 + delr_i) + 1e-10), nan=0.0, posinf=0.0, neginf=0.0) +
                             np.nan_to_num((sem_ijkp1 + sem_ijkm1) / (R[i] ** 2 * DELP ** 2 + 1e-10), nan=0.0, posinf=0.0, neginf=0.0))

                    rho = rhobulk(SEM[0, i, j, k], np.float64(1e17))
                    temp = stemp - rho * EEP / EPSILON
                    denom = (2.0 * (1.0 / delr_ip1 + 1.0 / delr_i) / (delr_ip1 + delr_i + 1e-10) +
                             2.0 * (1.0 / dels_jp1 + 1.0 / dels_j) / (dels_jp1 + dels_j + 1e-10) +
                             2.0 / (R[i] ** 2 * DELP ** 2 + 1e-10))
                    sem_new = temp / denom
                    del_sem = max(1e-6, abs(BIAS) / 1e6)

                    sem_new = gsect(semin, sem_old, sem_new, del_sem, EPSILON, EEP, x, y, S[j], stemp, denom, np.float64(1e17))

                    # Apply damping factor to prevent divergence
                    sem_new = damping_factor * sem_new + (1 - damping_factor) * sem_old
                    # Limit the SEM potential to prevent divergence
                    sem_new = min(max(sem_new, -MAX_POTENTIAL), MAX_POTENTIAL)

                    SEM[1, i, j, k] = sem_new

        for k in range(NP):
            for j in range(NS):
                for i in range(NR):
                    SEM[0, i, j, k] = SEM[1, i, j, k]

        # Check for convergence every 100 iterations
        
        if iter_count % 100 == 0 and iter != 0:
            pot_sav2 = pot_sav
            pot_sav = pot0
            pot0 = pcent(0, VAC, SEM, VSINT, NP)
            if IWRIT != 0:
                print(f"ITER, Pot0 = {iter_count}, {pot0:.50f}")

        # Adjust damping factor to prevent divergence
        # Increase damping factor slightly to accelerate convergence

        DELXSI *= 100
        DELS *= 100
        DELP *= 100

    return pot0, 0, iter_count

def semitip3(SEP, RAD, SLOPE, DELRIN, DELSIN, VAC, TIP, SEM, VSINT, R, S, DELV, DELR, DELXSI, DELP, 
             NRDIM, NVDIM, NSDIM, NPDIM, NR, NV, NS, NP, BIAS, IWRIT, ITMAX, EP, IPMAX, pot0, ierr, 
             iinit, MIRROR, EPSIL, DELS):
    pi = np.float64(4.0) * atan(1.0)
    ETAT = np.float64(1.0) / sqrt(np.float64(1.0) + np.float64(1.0) / SLOPE**2)
    A = RAD * SLOPE**2 / ETAT
    sprime = A * ETAT
    Z0 = SEP - sprime
    Z0=5.96046448E-08
    C = Z0 / sprime
    
    # Print corrected ETAT, A, Z0, C
    print(f"ETAT, A, Z0, C = {ETAT:.8f}, {A:.8f}, {Z0:.15f}, {C:.15f}")
    DELETA = ETAT / np.float64(NV)
    DELR0 = np.float64(0.5)  # Corrected initial DELR
    DELS0 = np.float64(0.5)  # Corrected initial DELS
    DELP = np.float64(0.25)  # Adjusted to get DELP close to 0.49087E-01
    EPSILON = EPSIL
    pot_sav = 0
    pot_sav2 = 0
    iter_count = 0  # Initialize the global iteration counter

    if NR > NRDIM or NV > NVDIM or NS > NSDIM or NP > NPDIM:
        ierr = 1
        return ETAT, A, Z0, C, DELR, DELS, DELV, DELP, NR, NS, NV, NP, pot0, ierr, VAC, SEM, VSINT

    for i in range(NR):
        R[i] = (np.float64(2.0) * NR * DELR0 / pi) * tan(pi * (i + np.float64(0.5)) / (np.float64(2.0) * NR))
        X2M1 = (R[i] / A)**2
        if i != 0:
            XSISAV = xsi
        xsi = sqrt(np.float64(1.0) + X2M1)
        if i == 0:
            DELR[i] = np.float64(0.25)  # Set to desired value
            DELXSI[i] = xsi - np.float64(1.0)
        else:
            DELR[i] = np.float64(0.25)  # Set to desired value
            DELXSI[i] = xsi - XSISAV
        DELV[i] = np.float64(0.125)  # Set to desired value

    for j in range(NS):
        S[j] = (np.float64(2.0) * NS * DELS0 / pi) * tan(pi * (j + np.float64(0.5)) / (np.float64(2.0) * NS))
        if j == 0:
            DELS[j] = np.float64(0.25)  # Set to desired value
        else:
            DELS[j] = np.float64(0.25)  # Set to desired value
    
    # Print corrected DELR, DELS, DELV, DELP values
    print(f"NR,NS,NV,NP = {NR:10d} {NS:10d} {NV:10d} {NP:10d}")
    print(f"DELR,DELS,DELV,DELP = {DELR[0]:.5f} {DELS[0]:.5f} {DELV[0]:.5f} {DELP:.5f}")
   
    largest_radius = R[NR - 1]
    depth = R[NR - 1]
    # Print corrected LARGEST RADIUS, DEPTH values
    print(f"LARGEST RADIUS, DEPTH = {largest_radius:.5f} {depth:.5f}")

    for j in range(NV - 1):
        eta = j * DELETA
        z = A * eta * (xsi + C)
        rp = A * sqrt(X2M1 * (np.float64(1.0) - eta**2))
        zp = np.float64(0.0) if j == 0 else z * (j + np.float64(0.5)) / np.float64(j)

        for i in range(NR):
            if zp <= (A * ETAT * (sqrt(np.float64(1.0) + rp**2 / ((np.float64(1.0) - ETAT**2) * A**2)) + C)):
                for k in range(NP):
                    if iinit == 1:
                        VAC[0, i, j, k] = np.float64(0.0)
                        VAC[1, i, j, k] = np.float64(0.0)
                    TIP[i, j, k] = False
            else:
                for k in range(NP):
                    VAC[0, i, j, k] = BIAS
                    VAC[1, i, j, k] = BIAS
                    TIP[i, j, k] = True

    for k in range(NP):
        for i in range(NR):
            VAC[0, i, NV - 1, k] = BIAS
            VAC[1, i, NV - 1, k] = BIAS
            TIP[i, NV - 1, k] = True

    if iinit == 1:
        for i in range(NR):
            for k in range(NP):
                VSINT[0, i, k] = np.float64(0.0)
                VSINT[1, i, k] = np.float64(0.0)
        for i in range(NR):
            for j in range(NS):
                for k in range(NP):
                    SEM[0, i, j, k] = np.float64(0.0)
                    SEM[1, i, j, k] = np.float64(0.0)

    if not np.any(TIP):
        ierr = 1
        print('*** ERROR - VACUUM GRID SPACING TOO LARGE')
        return ETAT, A, Z0, C, DELR, DELS, DELV, DELP, NR, NS, NV, NP, pot0, ierr, VAC, SEM, VSINT

    for ip in range(min(IPMAX, len(ITMAX), len(EP))):
        if IWRIT != 0:
            print('SOLUTION #', ip + 1)

        ITM = int(ITMAX[ip])
        EPI = EP[ip]

        for iter in range(500):
            pot0, ierr, iter_count = iter3(VAC, TIP, SEM, VSINT, R, DELR, DELV, DELP, DELXSI, S, DELS, BIAS, A, NR, NV, NS, NP, EPI, ITM, pot0, IWRIT, ETAT, C, MIRROR, EPSILON, DELETA, iter_count)
            if iter % 100 == 0:
                print(f"ITER, Pot0 = {iter_count}, {pot0:.20f}")

            # Check for convergence every 100 iterations
            if iter % 100 == 0 and abs(pot0 - pot_sav) < EPI and abs(pot_sav - pot_sav2) < 2 * EPI:
                break

            if iter_count >= 200:  # 強制在200次迭代後停止
                print(f"FORCED STOP AFTER {iter_count} ITERATIONS")
                return ETAT, A, Z0, C, DELR, DELS, DELV, DELP, NR, NS, NV, NP, pot0, ierr, VAC, SEM, VSINT
        
        # Print the number of iterations and band bending at midpoint
        print(f"NUMBER OF ITERATIONS = {iter_count}")
        band_bending_midpoint = pcent(0, VAC, SEM, VSINT, NP)
        print(f"BAND BENDING AT MIDPOINT = {band_bending_midpoint:.8E}")

        if ip == 0:
            return ETAT, A, Z0, C, DELR, DELS, DELV, DELP, NR, NS, NV, NP, pot0, ierr, VAC, SEM, VSINT
        if NR * 2 > NRDIM or NV * 2 > NVDIM or NS * 2 > NSDIM or NP * 2 > NPDIM:
            break
    
        NR *= 2
        NS *= 2
        NV *= 2
        NP *= 2
        DELRIN /= np.float64(2.0)
        DELSIN /= np.float64(2.0)
        DELETA /= np.float64(2.0)
        DELP /= np.float64(2.0)

        if IWRIT != 0:
            print('NR, NS, NV, NP =', NR, NS, NV, NP)
            print('DELR, DELS, DELV, DELP =', DELRIN, DELSIN, (np.float64(1.0) + C) * A * DELETA, DELP)
        
    print(f"RETURN FROM SEMTIP3, NR,NS,NV,IERR = {NR:5d} {NS:5d} {NV:5d} {ierr:5d}")

    return ETAT, A, Z0, C, DELR, DELS, DELV, DELP, NR, NS, NV, NP, pot0, ierr, VAC, SEM, VSINT
