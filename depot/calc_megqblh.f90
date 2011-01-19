subroutine calc_megqblh(ik,jk,ngumax,ngu,gu,igu,ngknr1,ngknr2,igkignr1,   &
  igkignr2,igkq,gvit,wfsvmt1,wfsvmt2,wfsvit1,wfsvit2,nmegqblh_,bmegqblh_, &
  megqblh_)
use modmain
implicit none
! arguments
integer, intent(in) :: ik
integer, intent(in) :: jk
integer, intent(in) :: ngumax
integer, intent(in) :: ngu(natmtot,ngvecme)
complex(4), intent(in) :: gu(ngumax,natmtot,ngvecme)
integer, intent(in) :: igu(4,ngumax,natmtot,ngvecme)
integer, intent(in) :: ngknr1
integer, intent(in) :: ngknr2
integer, intent(in) :: igkignr1(ngkmax)
integer, intent(in) :: igkignr2(ngkmax)
integer, intent(in) :: igkq
complex(8), intent(in) :: gvit(intgv(1,1):intgv(1,2),intgv(2,1):intgv(2,2), &
                               intgv(3,1):intgv(3,2))
complex(8), intent(in) :: wfsvmt1(lmmaxvr,nrfmax,natmtot,nspinor,nstsv)
complex(8), intent(in) :: wfsvmt2(lmmaxvr,nrfmax,natmtot,nspinor,nstsv)
complex(8), intent(in) :: wfsvit1(ngkmax,nspinor,nstsv)
complex(8), intent(in) :: wfsvit2(ngkmax,nspinor,nstsv)
integer, intent(in) :: nmegqblh_
integer, intent(in) :: bmegqblh_(2,nmegqblhmax)
complex(8), intent(out) :: megqblh_(ngvecme,nmegqblhmax)
! local variables
integer idx_g1,idx_g2,idx0,bs
integer ist1_prev
integer ig,ispn,ispn2,i,ist1,ist2,j,ias,lm1,lm2,io1,io2,j1,j2
logical l1
complex(8), allocatable :: mit(:,:)
complex(8), allocatable :: a1it(:) 
complex(8) a1mt(lmmaxvr,nrfmax,natmtot)
complex(8), allocatable :: wfir1(:)
complex(8), allocatable :: wfir2(:)
integer ivg1(3),ig1,ig2,ifg,ir
complex(8) zt1

! external
complex(8), external :: zdotu

megqblh_=zzero
ist1_prev=-1

! split G-vectors between processors
call idxbos(ngvecme,mpi_dims(2),mpi_x(2)+1,idx0,bs)
idx_g1=idx0+1
idx_g2=idx0+bs

allocate(a1it(ngknr2))
allocate(mit(ngknr1,ngknr2))
allocate(wfir1(ngrtot))
allocate(wfir2(ngrtot))

do ig=idx_g1,idx_g2
!  call timer_start(5)
!  call genpwit2(ngknr1,ngknr2,igkignr1,igkignr2, &
!    -(ivg(:,ig+gvecme1-1)+ivg(:,igkq)),gvit,mit)
!  call timer_stop(5)
  do ispn=1,nspinor
    ispn2=ispn
    if (lrtype.eq.1) ispn2=3-ispn
    do i=1,nmegqblh_
      ist1=bmegqblh_(1,i)
      ist2=bmegqblh_(2,i)
! precompute
      if (ist1.ne.ist1_prev) then
        a1it=zzero
        a1mt=zzero
        l1=.true.
        if (spinpol) then
          if (spinor_ud(ispn,ist1,ik).eq.0) l1=.false.
        endif
        if (l1) then
! muffin-tin part
          call timer_start(4)
          do ias=1,natmtot
            do j=1,ngu(ias,ig)
              lm1=igu(1,j,ias,ig)
              lm2=igu(2,j,ias,ig)
              io1=igu(3,j,ias,ig)
              io2=igu(4,j,ias,ig)
              a1mt(lm2,io2,ias)=a1mt(lm2,io2,ias)+&
                dconjg(wfsvmt1(lm1,io1,ias,ispn,ist1))*gu(j,ias,ig)
            enddo !j
          enddo !ias
          call timer_stop(4)
!          call timer_start(5)
!! interstitial part
!          call zgemv('T',ngknr1,ngknr2,zone,mit,ngknr1,&
!            dconjg(wfsvit1(:,ispn,ist1)),1,zzero,a1it,1)
!          call timer_stop(5)
        endif
        ist1_prev=ist1
      endif !ist1.ne.ist1_prev
      l1=.true.
      if (spinpol) then
        if (spinor_ud(ispn2,ist2,jk).eq.0) l1=.false.
      endif
      if (l1) then
        call timer_start(4)
! muffin-tin part
        do ias=1,natmtot
          megqblh_(ig,i)=megqblh_(ig,i)+zdotu(lmmaxvr,a1mt(1,1,ias),1,&
            wfsvmt2(1,1,ias,ispn2,ist2),1)
          do io2=2,nrfmax
            megqblh_(ig,i)=megqblh_(ig,i)+zdotu(16,a1mt(1,io2,ias),1,&
              wfsvmt2(1,io2,ias,ispn2,ist2),1)    
          enddo
        enddo !ias
        call timer_stop(4)
!! interstitial part
!        call timer_start(5) 
!        megqblh_(ig,i)=megqblh_(ig,i)+zdotu(ngknr2,wfsvit2(1,ispn2,ist2),1, &
!          a1it,1)
!        call timer_stop(5)
      endif
    enddo !i
  enddo !ispn
enddo !ig    

ist1_prev=-1
do ispn=1,nspinor
  ispn2=ispn
  if (lrtype.eq.1) ispn2=3-ispn
  do i=1,nmegqblh_
	ist1=bmegqblh_(1,i)
	ist2=bmegqblh_(2,i)
! precompute
	if (ist1.ne.ist1_prev) then
	  wfir1=zzero
	  l1=.true.
	  if (spinpol) then
		if (spinor_ud(ispn,ist1,ik).eq.0) l1=.false.
	  endif
	  if (l1) then
		call timer_start(5)
! interstitial part
		do ig1=1,ngknr1
		  ifg=igfft(igkignr1(ig1))
		  wfir1(ifg)=wfsvit1(ig1,ispn,ist1)
		enddo
		call zfftifc(3,ngrid,1,wfir1)
		do ir=1,ngrtot
		  wfir1(ir)=wfir1(ir)*cfunir(ir)
		enddo
        call zfftifc(3,ngrid,-1,wfir1)
		call timer_stop(5)
	  endif
	  ist1_prev=ist1
	endif !ist1.ne.ist1_prev
	l1=.true.
	if (spinpol) then
	  if (spinor_ud(ispn2,ist2,jk).eq.0) l1=.false.
	endif
	if (l1) then
! interstitial part
	  call timer_start(5) 
      do ig=1,ngvecme
        zt1=zzero
        do ig2=1,ngknr2
          ivg1(:)=ivg(:,igkignr2(ig2))-ivg(:,ig)-ivg(:,igkq)
          ifg=igfft(ivgig(ivg1(1),ivg1(2),ivg1(3)))
          zt1=zt1+dconjg(wfir1(ifg))*wfsvit2(ig2,ispn2,ist2)
	    enddo !ig2
	    megqblh_(ig,i)=megqblh_(ig,i)+zt1
	  enddo !ig
	  call timer_stop(5)
	endif
  enddo !i
enddo !ispn







if (mpi_dims(2).gt.1) then
  call d_reduce_cart(comm_cart_010,.false.,megqblh_,2*ngvecme*nmegqblhmax)
endif

!! interstitial part
!do ir=1,ngrtot
!  zrhoir(ir)=zrhoir(ir)*cfunir(ir)*omega
!enddo
!call zfftifc(3,ngrid,-1,zrhoir)
!do ig=1,ngvec_me
!  zrhofc(ig,2)=zrhoir(igfft1(ig))
!  zrhofc(ig,3)=zrhofc(ig,1)+zrhofc(ig,2)
!enddo

deallocate(a1it,mit)

return
end

!subroutine calcwfir(ngp,wfsvit,wfir)
!integer, intent(in) :: ngp
!complex(8), intent(in) :: wfsvit(ngkmax)
!complex(8), intent(out) :: wfir(ngrtot)
!use modmain
!implicit none
!real(8) t1
!integer igp,ifg
!
!wfir=zzero
!t1=1.d0/sqrt(omega)
!
!do igp=1,ngp
!  ifg=igfft(igpig(igp))
!  wfir(ifg)=t1*wfsvit(igp)
!enddo
!call zfftifc(3,ngrid,1,wfir)
!
!return
!end