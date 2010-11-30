module mod_wannier
implicit none

type wannier_transitions
! number of taken Wannier functions
  integer :: nwan
! global index of taken Wannier functions
  integer, allocatable :: iwan(:)
! total number of transitions (total number of <m| |nT> bra-kets)
  integer :: nwantran
! i-th transition
  integer, allocatable :: wantran(:,:)
! mapping from {m,n,T} to global index
  integer, allocatable :: iwantran(:,:,:,:,:) 
! translation limits
  integer :: tlim(2,3)  
! minimal distance
  real(8) :: mindist
! maximum distance
  real(8) :: maxdist
! list of all encountered translations
  integer :: nvt
  integer, allocatable :: vtl(:,:)
end type wannier_transitions

contains

subroutine genwantran(twantran,mindist,maxdist,waninc,all,diag)
use modmain
implicit none
! arguments
type(wannier_transitions), intent(out) :: twantran
real(8), intent(in) :: mindist
real(8), intent(in) :: maxdist
integer, optional, intent(in) :: waninc(nwantot)
logical, optional, intent(in) :: all
logical, optional, intent(in) :: diag
! local variables
integer n,i,n1,ias,jas,ntran,ntranmax,nvt,j,j1
logical ladd,lkeep,all_,diag_
logical, external :: wann_diel
real(8), parameter :: epswfocc=1d-8

all_=.false.
if (present(all)) all_=all
diag_=.false.
if (present(diag)) diag_=diag

allocate(twantran%iwan(nwantot))
if (present(waninc)) then
  twantran%iwan=-1
  i=0
  do n=1,nwantot
    if (waninc(n).ne.0) then
      i=i+1
      twantran%iwan(i)=n
    endif   
  enddo
  twantran%nwan=i
else
  twantran%nwan=nwantot
  do n=1,nwantot
    twantran%iwan(n)=n
  enddo
endif
twantran%mindist=mindist
twantran%maxdist=maxdist
call getnghbr(mindist,maxdist)
! get maximum possible number of WF transitions
ntranmax=0
do n=1,nwantot
  ias=wan_info(1,n)
  do i=1,nnghbr(ias)
    do n1=1,nwantot
      jas=wan_info(1,n1)
      if (jas.eq.inghbr(1,i,ias)) then
        ntranmax=ntranmax+nwannias(jas)
      endif
    enddo
  enddo
enddo
allocate(twantran%wantran(5,ntranmax))
twantran%wantran=0
ntran=0
do j=1,twantran%nwan
  n=twantran%iwan(j)
  ias=wan_info(1,n)
  do i=1,nnghbr(ias)
    do j1=1,twantran%nwan
      n1=twantran%iwan(j1)
      jas=wan_info(1,n1)
      if (jas.eq.inghbr(1,i,ias)) then
        ladd=.false.
        if (diag_) then
          if (n.eq.n1) ladd=.true.  
        else
! for integer occupancy numbers take only transitions between occupied and empty bands
          if (wann_diel().and.(abs(wann_occ(n)-wann_occ(n1)).gt.epswfocc)) ladd=.true.
! for fractional occupancies or other cases take all transitions
          if (.not.wann_diel().or.all_) ladd=.true.
        endif
        if (ladd) then
          ntran=ntran+1
          twantran%wantran(1,ntran)=n
          twantran%wantran(2,ntran)=n1
          twantran%wantran(3:5,ntran)=inghbr(3:5,i,ias)
        endif
      endif
    enddo !j1
  enddo !i
enddo !j
twantran%nwantran=ntran
twantran%tlim(1,1)=minval(twantran%wantran(3,:))
twantran%tlim(2,1)=maxval(twantran%wantran(3,:))
twantran%tlim(1,2)=minval(twantran%wantran(4,:))
twantran%tlim(2,2)=maxval(twantran%wantran(4,:))
twantran%tlim(1,3)=minval(twantran%wantran(5,:))
twantran%tlim(2,3)=maxval(twantran%wantran(5,:))
allocate(twantran%iwantran(nwantot,nwantot,twantran%tlim(1,1):twantran%tlim(2,1),&
  twantran%tlim(1,2):twantran%tlim(2,2),twantran%tlim(1,3):twantran%tlim(2,3)))
twantran%iwantran=-1
do i=1,twantran%nwantran
  twantran%iwantran(twantran%wantran(1,i),&
                    twantran%wantran(2,i),&
                    twantran%wantran(3,i),&
                    twantran%wantran(4,i),&
                    twantran%wantran(5,i))=i
enddo
allocate(twantran%vtl(3,twantran%nwantran))
twantran%vtl=0
nvt=0
do i=1,twantran%nwantran
  ladd=.true.
  do j=1,nvt
   if (twantran%vtl(1,j).eq.twantran%wantran(3,i).and.&
       twantran%vtl(2,j).eq.twantran%wantran(4,i).and.&
       twantran%vtl(3,j).eq.twantran%wantran(5,i)) ladd=.false.
  enddo
  if (ladd) then
    nvt=nvt+1
    twantran%vtl(:,nvt)=twantran%wantran(3:5,i)
  endif
enddo
twantran%nvt=nvt
return
end subroutine

subroutine deletewantran(twantran)
implicit none
type(wannier_transitions), intent(inout) :: twantran
if (allocated(twantran%iwan)) deallocate(twantran%iwan)
if (allocated(twantran%wantran)) deallocate(twantran%wantran)
if (allocated(twantran%iwantran)) deallocate(twantran%iwantran)
if (allocated(twantran%vtl)) deallocate(twantran%vtl)
return
end subroutine

subroutine printwantran(twantran)
implicit none
type(wannier_transitions), intent(in) :: twantran
integer i

write(*,*)'twantran%nwantran=',twantran%nwantran
do i=1,twantran%nwantran
  write(*,*)twantran%wantran(:,i)
enddo
return
end subroutine

end module
