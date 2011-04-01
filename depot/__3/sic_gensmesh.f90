subroutine sic_gensmesh
use modmain
use mod_sic
implicit none
integer itp,lm,lm1
real(8) a,tp(2),x1(3)
real(8), allocatable :: x(:,:),glw(:),glx(:)
complex(8), allocatable :: clm(:)
integer n,i,j,ias,jas,s1,nt,np,it,ip
logical lfound
integer, allocatable :: tptype(:)
!
!call getnghbr(-0.d0,50.d0)
!allocate(x(3,nnghbr(1)))
!allocate(tptype(nnghbr(1)))
!x=0.d0
!n=0
!ias=1
!s1=inghbr(6,nnghbr(ias),ias)
!do j=2,nnghbr(ias)
!  if (inghbr(6,j,ias).lt.s1) then
!    jas=inghbr(1,j,ias)
!    x1(:)=atposc(:,ias2ia(jas),ias2is(jas))+&
!      inghbr(3,j,ias)*avec(:,1)+&
!      inghbr(4,j,ias)*avec(:,2)+&
!      inghbr(5,j,ias)*avec(:,3)-atposc(:,ias2ia(ias),ias2is(ias))
!    x1=x1/sqrt(sum(x1**2))
!    lfound=.false.
!    do i=1,n
!      if (sum(abs(x1(:)-x(:,i))).lt.1d-10) lfound=.true.
!    enddo
!    if (.not.lfound) then
!      n=n+1
!      x(:,n)=x1(:)
!      tptype(n)=inghbr(6,j,ias)
!    endif
!    if (n.ge.s_ntp.and.inghbr(6,j+1,ias).gt.inghbr(6,j,ias)) exit
!  endif
!enddo
!if (n.lt.s_ntp) then
!  write(*,'("Error(sic_gensmesh): not enough covering points")')
!  write(*,'("  found : ",I6)')n
!  write(*,'("  minimum : ",I6)')s_ntp
!  call pstop
!endif
!if (mpi_grid_root()) then
!  write(*,'("[sic_gensmesh] number of covering points : ",I4)')n
!endif
!s_ntp=n

nt=lmaxwan+1
np=2*lmaxwan+1
s_ntp=nt*np

if (allocated(s_tp)) deallocate(s_tp)
allocate(s_tp(2,s_ntp))
if (allocated(s_x)) deallocate(s_x)
allocate(s_x(3,s_ntp))
if (allocated(s_tpw)) deallocate(s_tpw)
allocate(s_tpw(s_ntp))
if (allocated(s_rlmf)) deallocate(s_rlmf)
allocate(s_rlmf(lmmaxwan,s_ntp))
if (allocated(s_ylmf)) deallocate(s_ylmf)
allocate(s_ylmf(lmmaxwan,s_ntp))
if (allocated(s_rlmb)) deallocate(s_rlmb)
allocate(s_rlmb(s_ntp,lmmaxwan))
if (allocated(s_ylmb)) deallocate(s_ylmb)
allocate(s_ylmb(s_ntp,lmmaxwan))

! spherical grid with Gauss quadrature
allocate(glw(nt),glx(nt))
call gaulegf(-1.d0,1.d0,glx,glw,nt)
itp=0
do it=1,nt
  do ip=1,np
    itp=itp+1
    s_tp(1,itp)=acos(glx(it))
    s_tp(2,itp)=twopi*(ip-1)/np
    s_tpw(itp)=twopi*glw(it)/np
    s_x(:,itp)=(/sin(s_tp(1,itp))*cos(s_tp(2,itp)),&
                 sin(s_tp(1,itp))*sin(s_tp(2,itp)),&
                 glx(it)/)
  enddo
enddo
deallocate(glx,glw)

!call leblaik(s_ntp,s_x,s_tpw)

!do itp=1,s_ntp
!  s_x(:,itp)=x(:,itp)
!  call sphcrd(s_x(1,itp),a,s_tp(1,itp))
!enddo

!do i=1,s_ntp
!  do j=1,s_ntp
!    if (i.ne.j.and.sum(abs(s_tp(:,i)-s_tp(:,j))).lt.1d-10) then
!      write(*,'("Error(sic_gensmesh): equal points found")')
!      write(*,'("  tp(",I4,") : ",2G18.10)')i,s_tp(:,i)
!      write(*,'("  tp(",I4,") : ",2G18.10)')j,s_tp(:,j)
!      call pstop
!    endif
!  enddo
!enddo

! generate spherical harmonics
do itp=1,s_ntp
! very(!) approximate weight
  !s_tpw(itp)=fourpi/s_ntp
  !s_tpw(itp)=s_tpw(itp)*fourpi
  call genrlm(lmaxwan,s_tp(1,itp),s_rlmf(1,itp))
  call genylm(lmaxwan,s_tp(1,itp),s_ylmf(1,itp))
  do lm=1,lmmaxwan
    s_rlmb(itp,lm)=s_rlmf(lm,itp)*s_tpw(itp)
    s_ylmb(itp,lm)=dconjg(s_ylmf(lm,itp))*s_tpw(itp) 
  enddo
enddo

!call gen_tpw(tptype)

! generate backward transformation matrices
!call gen_bsht

!! check backward expansion
!allocate(clm(lmmaxwan))
!do lm=1,lmmaxwan
!  clm=zzero
!  do lm1=1,lmmaxwan
!    do itp=1,s_ntp
!      clm(lm1)=clm(lm1)+s_ylmb(itp,lm1)*s_ylmf(lm,itp)
!    enddo
!  enddo
!  a=0.d0 
!  do lm1=1,lmmaxwan
!    if (lm1.eq.lm) clm(lm1)=clm(lm1)-zone
!    a=a+abs(clm(lm1))
!  enddo
!  write(*,*)lm,a
!enddo
!deallocate(clm)
!call bstop

  


! generate Lebedev mesh for muffin-tins
if (allocated(mt_spx)) deallocate(mt_spx)
allocate(mt_spx(3,mt_ntp))
if (allocated(mt_tpw)) deallocate(mt_tpw)
allocate(mt_tpw(mt_ntp))
if (allocated(mt_ylmf)) deallocate(mt_ylmf)
allocate(mt_ylmf(lmmaxvr,mt_ntp))
call leblaik(mt_ntp,mt_spx,mt_tpw)
do itp=1,mt_ntp
  mt_tpw(itp)=mt_tpw(itp)*fourpi
  call sphcrd(mt_spx(:,itp),a,tp)
  call genylm(lmaxvr,tp,mt_ylmf(1,itp)) 
enddo

!call nfsft_init(lmaxwan,s_ntp,stp)
!deallocate(x)
!deallocate(tptype)
return
end

!subroutine gen_tpw(tpid)
!use modmain
!use mod_sic
!implicit none
!integer, intent(inout) :: tpid(*)
!integer i,j,k,maxid,itp,iter
!real(8), allocatable :: w(:),w2(:),gr(:)
!integer, allocatable :: tpid2(:)
!real(8) t1,t2,t3
!real(8), external :: wtp_func
!
!j=minval(tpid(1:s_ntp))
!tpid(1:s_ntp)=tpid(1:s_ntp)-j+1
!maxid=maxval(tpid(1:s_ntp))
!allocate(tpid2(s_ntp))
!tpid2=0
!j=0
!do i=1,maxid
!  if (any(tpid(1:s_ntp).eq.i)) then
!    j=j+1
!    do k=1,s_ntp
!      if (tpid(k).eq.i) then
!        tpid2(k)=j
!        tpid(k)=0
!      endif
!    enddo
!  endif
!enddo
!tpid(1:s_ntp)=tpid2(1:s_ntp)
!deallocate(tpid2)
!maxid=maxval(tpid(1:s_ntp))
!
!allocate(w(maxid))
!w=fourpi/s_ntp
!
!allocate(w2(maxid))
!allocate(gr(maxid))
!
!
!
!
!do iter=1,5
!  t1=wtp_func(maxid,w,tpid)
!  write(*,*)t1
!  
!  gr=0.d0
!  do i=1,maxid
!    w2=w
!    w2(i)=w2(i)+0.001d0
!    t3=0.d0
!    !do itp=1,s_ntp
!    !  t3=t3+w2(tpid(itp))
!    !enddo
!    !w2=w2*fourpi/t3
!    t2=wtp_func(maxid,w2,tpid)
!    gr(i)=(t2-t1)/0.001d0
!  enddo
!  !gr=gr
!  !write(*,*)"gr=",gr
!  w=w-gr*0.00001
!
!  !t3=0.d0
!  !do itp=1,s_ntp
!  !  t3=t3+w(tpid(itp))
!  !enddo
!  !w=w*fourpi/t3
!
!
!enddo
!  
!
!  write(*,*)"w=",w
!
!!do i=1,s_ntp
!!  write(*,*)"tp=",s_tp(:,i)," id=",tpid(i)
!!enddo
!
!
!call bstop
!return
!end
!
!real(8) function wtp_func(n,w,tpid)
!use modmain
!use mod_sic
!implicit none
!integer, intent(in) :: n
!real(8), intent(in) :: w(n)
!integer, intent(in) :: tpid(s_ntp)
!integer lm1,lm2,itp
!real(8) t1,t2
!complex(8) zt1
!
!t1=0.d0
!do lm1=1,lmmaxwan
!  do lm2=1,lmmaxwan
!    zt1=zzero
!    do itp=1,s_ntp
!      zt1=zt1+dconjg(s_ylmf(lm1,itp))*s_ylmf(lm2,itp)*w(tpid(itp))
!    enddo
!    if (lm1.eq.lm2) zt1=zt1-zone
!    t1=t1+abs(zt1)
!  enddo
!enddo
!t1=t1/lmmaxwan/lmmaxwan
!t2=0.d0
!do itp=1,s_ntp
!  t2=t2+w(tpid(itp))
!enddo
!wtp_func=t1+abs(t2-fourpi)
!return
!end
!
!subroutine gen_bsht
!use modmain
!use mod_sic
!implicit none
!integer ierr
!real(8), allocatable :: o(:,:)
!real(8), allocatable :: a(:,:)
!complex(8), allocatable :: zo(:,:)
!complex(8), allocatable :: za(:,:)
!logical texist,tgen
!integer lmmaxwan_,s_ntp_,itp
!real(8), allocatable :: s_tp_(:,:)
!!
!tgen=.false.
!inquire(file="bsht",exist=texist)
!if (texist) then
!  if (mpi_grid_root()) then
!    open(300,file="bsht",form="unformatted")
!    read(300)lmmaxwan_
!    read(300)s_ntp_
!    allocate(s_tp_(2,s_ntp_))
!    read(300)s_tp_
!    if (lmmaxwan_.ne.lmmaxwan) tgen=.true.
!    if (s_ntp_.ne.s_ntp) then
!      tgen=.true.
!    else
!      do itp=1,s_ntp
!        if (s_tp_(1,itp).ne.s_tp(1,itp)) tgen=.true.
!        if (s_tp_(2,itp).ne.s_tp(2,itp)) tgen=.true.
!      enddo
!    endif
!    if (.not.tgen) then
!      read(300)s_ylmb
!      read(300)s_rlmb
!    endif
!    close(300)
!    deallocate(s_tp_)
!  endif
!  call mpi_grid_bcast(tgen)
!else
!  tgen=.true.
!endif
!if (tgen) then
!  if (mpi_grid_root()) write(*,'("[gen_bsht] generating transformation matrices")')
!  allocate(zo(lmmaxwan,lmmaxwan))
!  allocate(za(lmmaxwan,lmmaxwan))
!! compute overlap matrix o_{lm,l'm'}=<Y_{lm}|Y_{l'm'}> 
!!  note: zgemm computes conjugated overlap matrix
!  call zgemm('N','C',lmmaxwan,lmmaxwan,s_ntp,zone,s_ylmf,lmmaxwan,&
!    s_ylmf,lmmaxwan,zzero,zo,lmmaxwan)
!  zo=dconjg(zo)
!! calculate S=O^{-1/2}
!  call isqrtzhe(lmmaxwan,zo,ierr) 
!  if (ierr.ne.0) then
!    write(*,'("Error(gen_bsht): overlap matrix of complex spherical harmonics&
!     & is degenerate")')
!    call pstop
!  endif
!  call zgemm('N','C',lmmaxwan,lmmaxwan,lmmaxwan,zone,zo,lmmaxwan,zo,lmmaxwan,&
!    zzero,za,lmmaxwan)
!  call zgemm('C','T',s_ntp,lmmaxwan,lmmaxwan,zone,s_ylmf,lmmaxwan,za,lmmaxwan,&
!    zzero,s_ylmb,s_ntp)
!  deallocate(zo,za)
!  allocate(o(lmmaxwan,lmmaxwan))
!  allocate(a(lmmaxwan,lmmaxwan))
!! compute overlap matrix o_{lm,l'm'}=<R_{lm}|R_{l'm'}> 
!  call dgemm('N','T',lmmaxwan,lmmaxwan,s_ntp,1.d0,s_rlmf,lmmaxwan,&
!    s_rlmf,lmmaxwan,0.d0,o,lmmaxwan)
!! calculate S=O^{-1/2}
!  call isqrtdsy(lmmaxwan,o,ierr) 
!  if (ierr.ne.0) then
!    write(*,'("Error(gen_bsht): overlap matrix of real spherical harmonics&
!     & is degenerate")')
!    call pstop
!  endif
!  call dgemm('N','T',lmmaxwan,lmmaxwan,lmmaxwan,1.d0,o,lmmaxwan,o,lmmaxwan,&
!    0.d0,a,lmmaxwan)
!  call dgemm('T','T',s_ntp,lmmaxwan,lmmaxwan,1.d0,s_rlmf,lmmaxwan,a,lmmaxwan,&
!    0.d0,s_rlmb,s_ntp)
!   deallocate(a,o)
!else
!  call mpi_grid_bcast(s_ylmb(1,1),s_ntp*lmmaxwan)
!  call mpi_grid_bcast(s_rlmb(1,1),s_ntp*lmmaxwan)
!endif
!if (mpi_grid_root().and.tgen) then
!  open(300,file="bsht",form="unformatted",status="replace")
!  write(300)lmmaxwan
!  write(300)s_ntp
!  write(300)s_tp
!  write(300)s_ylmb
!  write(300)s_rlmb
!  close(300)
!endif
!return
!end


!subroutine test_sht1
!use modmain
!use mod_sic
!implicit none
!integer itp,i,j,ierr
!complex(8), allocatable :: s_ylmf_ort(:,:)
!
!allocate(s_ylmf_ort(lmmaxwan,s_ntp))
!allocate(s_ylmo(lmmaxwan,lmmaxwan))
!s_ylmo=zzero
!do i=1,lmmaxwan
!  do j=1,lmmaxwan
!    do itp=1,s_ntp
!      s_ylmo(i,j)=s_ylmo(i,j)+dconjg(s_ylmf(i,itp))*s_ylmf(j,itp)
!    enddo
!  enddo
!enddo
!call isqrtzhe(lmmaxwan,s_ylmo,ierr) 
!if (ierr.ne.0) then
!  write(*,*)"Error in isqrtzhe"
!  call pstop
!endif
!s_ylmf_ort=zzero
!do i=1,lmmaxwan
!  do j=1,lmmaxwan
!    s_ylmf_ort(i,:)=s_ylmf_ort(i,:)+s_ylmo(j,i)*s_ylmf(j,:)
!  enddo
!enddo
!do i=1,lmmaxwan
!  s_ylmb(:,i)=dconjg(s_ylmf_ort(i,:))
!enddo
!deallocate(s_ylmf_ort)
!
!return
!end

!subroutine test_sht
!use modmain
!use mod_sic
!implicit none
!integer ilm,jlm
!complex(8), allocatable :: flm(:)
!complex(8), allocatable :: ftp(:)
!real(8) t1,t2
!
!allocate(flm(lmmaxwan))
!allocate(ftp(s_ntp))
!
!do ilm=1,lmmaxwan
!  flm=zzero
!  ftp=zzero
!  flm(ilm)=zone
!  call nfsft_ft(lmaxwan,s_ntp,1,flm,ftp)
!  write(*,*)"diff=",sum(abs(s_ylmf(ilm,:)-ftp(:)))
!  flm=zzero
!  call nfsft_bt(lmaxwan,s_ntp,1,ftp,flm)
!  flm(ilm)=flm(ilm)-zone
!  t1=0.d0
!  t2=0.d0
!  do jlm=1,lmmaxwan
!    t1=max(t1,abs(flm(jlm)))
!    if (jlm.ne.ilm) t2=max(t2,abs(flm(jlm)))
!  enddo
!  write(*,*)"l:",lm2l(ilm),"m:",lm2m(ilm)," max.err. ",t1,t2
!enddo
!deallocate(flm,ftp)
!call bstop
!
!
!return
!end
!

!subroutine test1(ntp,lmax)
!use modmain
!implicit none
!integer, intent(in) :: ntp
!integer, intent(in) :: lmax
!integer itp,lm,lmmax,itp1
!real(8) a,tp(2)
!complex(8) z1
!real(8), allocatable :: spx(:,:)
!real(8), allocatable :: tpw(:)
!complex(8), allocatable :: ylmf(:,:)
!complex(8), allocatable :: ylmb(:,:)
!
!lmmax=(lmax+1)**2
!
!allocate(spx(3,ntp))
!allocate(tpw(ntp))
!allocate(ylmf(lmmax,ntp))
!allocate(ylmb(ntp,lmmax))
!! Lebedev-Laikov mesh
!call leblaik(ntp,spx,tpw)
!! get (theta,phi) of each spx vector and generate spherical harmonics
!do itp=1,ntp                   
!  tpw(itp)=tpw(itp)*fourpi
!  call sphcrd(spx(1,itp),a,tp)
!  call genylm(lmax,tp,ylmf(1,itp))
!  do lm=1,lmmax
!    ylmb(itp,lm)=dconjg(ylmf(lm,itp))*tpw(itp) 
!  enddo  
!enddo 
!a=0.d0
!do itp=1,ntp
!  do itp1=1,ntp
!    z1=zzero
!    do lm=1,lmmax
!      z1=z1+ylmb(itp,lm)*ylmf(lm,itp1)
!    enddo
!    if (itp.eq.itp1) z1=z1-zone
!    a=max(a,abs(z1))
!    !if (itp.ne.itp1) a=max(a,abs(z1))
!  enddo
!enddo
!if (mpi_grid_root()) then
!  write(*,'("[test1] l = ",I4," ntp = ",I4)')lmax,ntp
!  write(*,'("[test1] Lebedev quadrature completeness error : ",G18.10)')a
!  write(*,*)
!endif
!deallocate(spx,tpw,ylmf,ylmb)
!return
!end
!