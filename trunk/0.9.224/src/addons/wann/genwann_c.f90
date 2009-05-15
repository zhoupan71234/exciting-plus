subroutine genwann_c(ik,e,wfsvmt,wann_c_)
use modmain
implicit none
! arguments
integer, intent(in) :: ik
real(8), intent(in) :: e(nstsv)
complex(8), intent(in) :: wfsvmt(lmmaxvr,nrfmax,natmtot,nspinor,nstsv)
complex(8), intent(out) :: wann_c_(nwann,nstsv)

complex(8), allocatable :: prjao(:,:)
complex(8), allocatable :: s(:,:)
integer ispn,i,j,n,m1,m2,io1,io2,ias,lm1,lm,ierr,l,itype
logical l1

!write(*,*)'ik=',ik
!do i=1,nstsv
!  do ispn=1,nspinor
!    do ias=1,natmtot
!      do io1=1,nrfmax
!        do lm=1,lmmaxvr
!          write(*,*)'lm=',lm,'io=',io1,'ias=',ias,'ispn=',ispn,'i=',i,'wfsvmt=',wfsvmt(lm,io1,ias,i,ispn)
!        enddo
!      enddo
!    enddo
!  enddo
!enddo
! compute <\psi|g_n>
allocate(prjao(nwann,nstsv))
prjao=zzero
do n=1,nwann
  ias=iwann(1,n)
  lm=iwann(2,n)
  l=lm2l(lm)
  ispn=iwann(3,n)
  itype=iwann(4,n)
  do j=1,nstsv
    l1=.false.
    if (wann_use_eint) then
      if (e(j).ge.wann_eint(1,itype).and.e(j).le.wann_eint(2,itype)) l1=.true.
    else
      if (j.ge.wann_nint(1,itype).and.j.le.wann_nint(2,itype)) l1=.true.
    endif
    if (l1) then
      do m1=-l,l
        lm1=idxlm(l,m1)
        io2=2
        do io1=1,nrfmax
          prjao(n,j)=prjao(n,j)+dconjg(wfsvmt(lm1,io1,ias,ispn,j)) * &
            urfprod(l,io1,io2,ias)*rylm_lcs(lm,lm1,ias)
        enddo !io1
      enddo !m
      if (abs(prjao(n,j)).lt.1d-2) prjao(n,j)=zzero
    endif
  enddo !j
enddo !n

allocate(s(nwann,nwann))
! compute ovelap matrix
s=zzero
do m1=1,nwann
  do m2=1,nwann
    do j=1,nstsv
      s(m1,m2)=s(m1,m2)+prjao(m1,j)*dconjg(prjao(m2,j))
    enddo
  enddo
enddo
! compute S^{-1/2}
call isqrtzhe(nwann,s,ierr)
if (ierr.ne.0) then
  write(*,*)
  write(*,'("Warning(genwann_c): failed to calculate S^{-1/2}")')
  write(*,'("  k-point : ",I4)')ik
  write(*,'("  iteration : ",I4)')iscl
  write(*,'("  number of linear dependent WFs : ",I4)')ierr
  write(*,'("Non-orthogonal WFs will be used")')
!  do n=1,nwann
!    itype=iwann(4,n)
!    write(*,*)
!    write(*,'(" n : ",I4,"  type : ",I4)')n,itype
!    write(*,'("   |<\psi_i|\phi_n>| : ")')
!    write(*,'(6X,10G18.10)')abs(prjao(n,:))
!    write(*,'("   sum(abs(|..|)) : ",G18.10)')sum(abs(prjao(n,:)))
!  enddo
  write(*,*)
endif
! compute Wannier function expansion coefficients
wann_c_=zzero
if (ierr.eq.0) then
  do m1=1,nwann
    do m2=1,nwann
      wann_c_(m1,:)=wann_c_(m1,:)+prjao(m2,:)*dconjg(s(m2,m1))
    enddo
  enddo
else
  wann_c_=prjao
endif
deallocate(s)
deallocate(prjao)

return
end