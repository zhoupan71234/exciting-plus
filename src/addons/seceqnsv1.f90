subroutine seceqnsv1(ikloc,apwalm,evalfv,evecfv,evecsv)
use modmain
implicit none
! arguments
integer, intent(in) :: ikloc
complex(8), intent(in) :: apwalm(ngkmax,apwordmax,lmmaxapw,natmtot)
real(8), intent(in) :: evalfv(nstfv)
complex(8), intent(in) :: evecfv(nmatmax,nstfv)
complex(8), intent(out) :: evecsv(nstsv,nstsv)
! local variables
integer is,ias,ik
integer ist,jst,i,j,ispn
integer ir,igk,j1,j2,io1,io2,l1,l2,lm1,lm2,lm3
integer lwork,info
real(8) cb
complex(8) zt1,zt2
! allocatable arrays
real(8), allocatable :: bir(:)
real(8), allocatable :: rwork(:)
complex(8), allocatable :: work(:)
complex(8), allocatable :: wfmt(:,:,:,:)
complex(8), allocatable :: wfbfmt(:,:,:,:)
complex(8), allocatable :: zfft(:)
complex(8), allocatable :: wfbfit(:,:)
complex(8), allocatable :: zm1(:,:,:,:)
! external functions
complex(8) zdotc,zfmtinp
external zdotc,zfmtinp
!
ik=mpi_grid_map(nkpt,dim_k,loc=ikloc)
call timer_start(t_seceqnsv)
call timer_start(t_seceqnsv_setup)
! no calculation of second-variational eigenvectors
if (.not.tevecsv) then  
  do i=1,nstsv
    evalsv(i,ik)=evalfv(i)
  end do
  evecsv(:,:)=0.d0
  do i=1,nstsv
    evecsv(i,i)=1.d0
  end do
  return
end if
! generate first-variational wave functions
allocate(wfmt(lmmaxvr,nufrmax,natmtot,nstfv))
call genwffvmt(lmaxvr,lmmaxvr,ngk(1,ik),evecfv,apwalm,wfmt)
allocate(wfbfmt(lmmaxvr,nufrmax,natmtot,nstfv))
allocate(zm1(lmmaxvr,lmmaxvr,nufrmax,nufrmax))
! multiply wave-function with magnetic field
wfbfmt=zzero
do ias=1,natmtot
  is=ias2is(ias)
  zm1=zzero
  j1=0
  do l1=0,lmaxvr
    do io1=1,nufr(l1,is)
      j1=j1+1
      do lm1=l1**2+1,(l1+1)**2
        j2=0
        do l2=0,lmaxvr
          do io2=1,nufr(l2,is)
            j2=j2+1
            do lm2=l2**2+1,(l2+1)**2
              zt2=zzero
              do lm3=1,lmmaxvr
                zt2=zt2+sv_gntyry(lm3,lm2,lm1)*sv_ubu(lm3,j2,j1,ias,1)
              enddo
              zm1(lm2,lm1,io2,io1)=zt2
            enddo !lm2
          enddo !io2
        enddo !l2
      enddo !lm1
    enddo !io1
  enddo !l1
  do ist=1,nstfv
    do l1=0,lmaxvr
      do io1=1,nufr(l1,is)
        do lm1=l1**2+1,(l1+1)**2
          zt1=zzero
          do l2=0,lmaxvr
            do io2=1,nufr(l2,is)
              do lm2=l2**2+1,(l2+1)**2
                zt1=zt1+wfmt(lm2,io2,ias,ist)*zm1(lm2,lm1,io2,io1)
              enddo
            enddo
          enddo !l2
          wfbfmt(lm1,io1,ias,ist)=zt1
        enddo
      enddo
    enddo !l1
  enddo
enddo !ias
deallocate(zm1)
allocate(bir(ngrtot))
allocate(zfft(ngrtot))
allocate(wfbfit(ngkmax,nstfv))
cb=gfacte/(4.d0*solsc)
do ir=1,ngrtot
  bir(ir)=bxcir(ir,1)+cb*bfieldc(3)
end do
wfbfit=zzero
do ist=1,nstfv
  zfft(:)=zzero
  do igk=1,ngk(1,ik)
    zfft(igfft(igkig(igk,1,ikloc)))=evecfv(igk,ist)
  end do
! Fourier transform wavefunction to real-space
  call zfftifc(3,ngrid,1,zfft)
! multiply with magnetic field and transform to G-space
  do ir=1,ngrtot
    zfft(ir)=zfft(ir)*bir(ir)*cfunir(ir)
  enddo
  call zfftifc(3,ngrid,-1,zfft)
  do igk=1,ngk(1,ik)
    wfbfit(igk,ist)=zfft(igfft(igkig(igk,1,ikloc)))
  end do
enddo
evecsv=zzero
do ist=1,nstfv
  do jst=1,nstfv
    i=ist
    j=jst
    if (i.le.j) then
      evecsv(i,j)=evecsv(i,j)+zdotc(lmmaxvr*nufrmax*natmtot,&
        wfmt(1,1,1,ist),1,wfbfmt(1,1,1,jst),1)+zdotc(ngk(1,ik),evecfv(1,ist),1,wfbfit(1,jst),1)
    endif
    i=ist+nstfv
    j=jst+nstfv
    if (i.le.j) then
      evecsv(i,j)=evecsv(i,j)-zdotc(lmmaxvr*nufrmax*natmtot,&
        wfmt(1,1,1,ist),1,wfbfmt(1,1,1,jst),1)-zdotc(ngk(1,ik),evecfv(1,ist),1,wfbfit(1,jst),1)
    endif
  enddo
enddo
deallocate(wfmt,wfbfmt,bir,zfft,wfbfit)
! add the diagonal first-variational part
i=0
do ispn=1,nspinor
  do ist=1,nstfv
    i=i+1
    evecsv(i,i)=evecsv(i,i)+evalfv(ist)
  end do
end do
call timer_stop(t_seceqnsv_setup)
if (mpi_grid_root((/dim2/))) then
  if (sic) call sic_hunif(ikloc,evecsv)
  call timer_start(t_seceqnsv_diag)
! diagonalise second-variational Hamiltonian
  allocate(rwork(3*nstsv))
  lwork=2*nstsv
  allocate(work(lwork))
  if (ndmag.eq.1) then
! collinear: block diagonalise H
    call zheev('V','U',nstfv,evecsv,nstsv,evalsv(:,ik),work,lwork,rwork,info)
    if (info.ne.0) goto 20
    i=nstfv+1
    call zheev('V','U',nstfv,evecsv(i,i),nstsv,evalsv(i,ik),work,lwork,rwork,info)
    if (info.ne.0) goto 20
    do i=1,nstfv
      do j=1,nstfv
        evecsv(i,j+nstfv)=0.d0
        evecsv(i+nstfv,j)=0.d0
      end do
    end do
  else
! non-collinear or spin-unpolarised: full diagonalisation
    call zheev('V','U',nstsv,evecsv,nstsv,evalsv(:,ik),work,lwork,rwork,info)
    if (info.ne.0) goto 20
  end if
  deallocate(rwork,work)
  call timer_stop(t_seceqnsv_diag)
endif
call mpi_grid_bcast(evecsv(1,1),nstsv*nstsv,dims=(/dim2/))
call mpi_grid_bcast(evalsv(1,ik),nstsv,dims=(/dim2/))
call timer_stop(t_seceqnsv)
timesv=0.d0
return
20 continue
write(*,*)
write(*,'("Error(seceqnsv1): diagonalisation of the second-variational &
 &Hamiltonian failed")')
write(*,'(" for k-point ",I8)') ik
write(*,'(" ZHEEV returned INFO = ",I8)') info
write(*,*)
call pstop  
return
end subroutine
