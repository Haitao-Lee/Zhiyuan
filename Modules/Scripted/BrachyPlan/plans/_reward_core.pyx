# cython: boundscheck=False, wraparound=False, cdivision=True

from cython.parallel import prange
from libc.math cimport fmax


def _dvh_oar_jit(
    double[:] dose,
    int[:]    target_idx,
    int[:]    non_target_idx,
    double    thr_target,
    double    thr_oar,
    bint      count_out=True,
):
    """
    Parallel DVH & OAR damage calculator (Cython version).

    Parameters
    ----------
    dose : memoryview of float64
        Flattened dose grid.
    target_idx : memoryview of int32
        Flat indices of target voxels.
    non_target_idx : memoryview of int32
        Flat indices of OAR voxels.
    thr_target : float
        DVH threshold [Gy].
    thr_oar : float
        OAR penalty threshold [Gy].
    count_out : bool
        If False, skip OAR loop.

    Returns
    -------
    (dvh, oar) where oar is float or None
    """
    cdef:
        Py_ssize_t n_target = target_idx.shape[0]
        Py_ssize_t n_non_target = non_target_idx.shape[0]
        Py_ssize_t i
        double target_sum = 0.0
        double oar_sum = 0.0
        double dvh
        double oar_val

    # ---- parallel over target voxels ----
    for i in prange(n_target, nogil=True, schedule='static'):
        if dose[target_idx[i]] > thr_target:
            target_sum += 1.0

    dvh = target_sum / n_target

    if count_out:
        # ---- parallel over OAR voxels ----
        for i in prange(n_non_target, nogil=True, schedule='static'):
            if dose[non_target_idx[i]] > thr_oar:
                oar_sum += 1.0
        oar_val = <double>n_target / fmax(0.1, oar_sum)
        return dvh, oar_val
    else:
        return dvh, None
