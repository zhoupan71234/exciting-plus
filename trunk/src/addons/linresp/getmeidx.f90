subroutine getmeidx(req,occsvnr,evalsvnr)
use modmain
#ifdef _MPI_
use mpi
#endif
implicit none
! arguments
logical, intent(in) :: req
real(8), intent(in) :: occsvnr(nstsv,nkptnr)
real(8), intent(in) :: evalsvnr(nstsv,nkptnr)

integer i,ik,jk,ist1,ist2,ikloc
logical laddme,ldocc
real(8) d1,min_e12
logical l11,l12,l21,l22,le1,le2
logical leint
integer, external :: iknrglob2

leint=.true.
lr_n1=int(lr_e1)
lr_n2=int(lr_e2)
if (abs(lr_n1-lr_e1).lt.1d-8.and.abs(lr_n2-lr_e2).lt.1d-8) then
  leint=.false.
endif
if (req.and.wproc) then
  write(150,*)
  if (leint) then
    write(150,'("Band interval (Ha) : ",2F8.3)')lr_e1,lr_e2
  else
    write(150,'("Band interval : ",2I4)')lr_n1,lr_n2
  endif
endif
if (req) then
  nmemax=0
  min_e12=100.d0
endif
do ikloc=1,nkptnr_loc
  ik=iknrglob2(ikloc,mpi_x(1))
  jk=idxkq(1,ik)
  i=0
  do ist1=1,nstsv
    do ist2=1,nstsv
      if (leint) then
        le1=evalsvnr(ist1,ik).ge.lr_e1.and.evalsvnr(ist1,ik).le.lr_e2
        le2=evalsvnr(ist2,jk).ge.lr_e1.and.evalsvnr(ist2,jk).le.lr_e2
      else
        if (ncmag) then
          le1=ist1.ge.lr_n1.and.ist1.le.lr_n2
          le2=ist2.ge.lr_n1.and.ist2.le.lr_n2
        else
          le1=(mod(ist1-1,nstfv)+1).ge.lr_n1.and.(mod(ist1-1,nstfv)+1).le.lr_n2
          le2=(mod(ist2-1,nstfv)+1).ge.lr_n1.and.(mod(ist2-1,nstfv)+1).le.lr_n2
        endif
      endif
      d1=occsvnr(ist1,ik)-occsvnr(ist2,jk)
      ldocc=abs(d1).gt.1d-5
      laddme=.false.
      if ((ldocc.or.(lwannresp.and..not.lwanndiel)).and.(le1.and.le2)) then
        if (.not.spinpol) then
          laddme=.true.
        else
          l11=spinor_ud(1,ist1,ik).eq.1.and.spinor_ud(1,ist2,jk).eq.1
          l12=spinor_ud(1,ist1,ik).eq.1.and.spinor_ud(2,ist2,jk).eq.1
          l21=spinor_ud(2,ist1,ik).eq.1.and.spinor_ud(1,ist2,jk).eq.1
          l22=spinor_ud(2,ist1,ik).eq.1.and.spinor_ud(2,ist2,jk).eq.1
          if (lrtype.eq.0.and.(l11.or.l22)) laddme=.true.
          if (lrtype.eq.1.and.(l12.or.l21)) laddme=.true.
        endif
      endif
      if (laddme) then
        i=i+1
        if (.not.req) then
          ime(1,i,ikloc)=ist1
          ime(2,i,ikloc)=ist2
          ime(3,i,ikloc)=1 
          docc(i,ikloc)=d1
        endif
        if (req) then
          min_e12=min(min_e12,abs(evalsvnr(ist1,ik)-evalsvnr(ist2,jk)))
        endif
      endif
    enddo
  enddo
  if (.not.req) nme(ikloc)=i
  if (req) nmemax=max(nmemax,i)
enddo !ikloc

if (req) then
#ifdef _MPI_
  call d_reduce_cart2(comm_cart_100,.false.,min_e12,1,MPI_MIN)
#endif
  if (wproc) then
    write(150,*)
    write(150,'("Minimal energy transition (eV) : ",F12.6)')min_e12*ha2ev
  endif
endif

return
end

