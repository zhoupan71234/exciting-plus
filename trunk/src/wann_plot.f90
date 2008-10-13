subroutine wann_plot
use modmain
use modwann
#ifdef _MPI_
use mpi
#endif
implicit none

real(8) r(3),r1(3),t(3),d
real(8) bound3d(3,3),orig3d(3)
real(8) bound2d(3,2),orig2d(3)
complex(4), allocatable :: wf(:,:)

integer ntr(3),i,ivec,nrxyz(3),nrtot
integer i1,i2,i3,ir,n,ierr
integer mtord,ik,ikloc,ispn,istfv,j,ig
complex(8), allocatable :: evecfv(:,:,:)
complex(8), allocatable :: evecsv(:,:)
complex(8), allocatable :: evec(:,:,:)
complex(8), allocatable :: acoeff(:,:,:,:,:)
complex(8), allocatable :: acoefftmp(:,:,:,:,:)
complex(8), allocatable :: apwalm(:,:,:,:)
complex(8), allocatable :: bcoeff(:,:,:,:,:,:,:)
complex(8), allocatable :: evec1(:,:,:)
complex(8) zt1
character*8 fname
real(8) x(2),alph
logical, parameter :: wf3d=.false.
integer tlim(2,3)
call init0
call init1

call wann_init

! read density and potentials from file
call readstate
! read Fermi energy from file
call readfermi
! generate the core wavefunctions and densities
call gencore
! find the new linearisation energies
call linengy
! generate the APW radial functions
call genapwfr
! generate the local-orbital radial functions
call genlofr

if (iproc.eq.0) then
!  call get_a_ort
endif
!call zsync(a_ort,wf_dim*nstfv*wann_nspins*nkpt,.false.,.true.)



! Cartesian coordinates of boundary and origin
bound3d(:,1)=(/16.d0,0.d0,0.d0/)
bound3d(:,2)=(/0.d0,16.d0,0.d0/)
bound3d(:,3)=(/0.d0,0.d0,16.d0/)
orig3d(:)=(/-8.d0,-8.d0,-8.d0/)

bound2d(:,1)=(/20.d0,0.d0,0.d0/)
bound2d(:,2)=(/0.d0,20.d0,0.d0/)
orig2d(:)=(/-8.d0,-8.d0, 0.d0/)

nrxyz(:)=(/200,200,200/)

if (wf3d) then
  nrtot=nrxyz(1)*nrxyz(2)*nrxyz(3)
else
  nrtot=nrxyz(1)*nrxyz(2)
endif
allocate(wf(wf_dim,nrtot))

! find the translation limits
tlim(1,:)=1000
tlim(2,:)=-1000
if (wf3d) then
  do i1=0,1
    do i2=0,1
      do i3=0,1
        r(:)=orig3d(:)+i1*bound3d(:,1)+i2*bound3d(:,2)+i3*bound3d(:,3)
        call getntr(r,ntr)
        do i=1,3
          tlim(1,i)=min(ntr(i),tlim(1,i))
          tlim(2,i)=max(ntr(i),tlim(2,i))
        enddo
      enddo
    enddo
  enddo
else
  do i1=0,1
    do i2=0,1
      r(:)=orig2d(:)+i1*bound2d(:,1)+i2*bound2d(:,2)
      call getntr(r,ntr)
      do i=1,3
        tlim(1,i)=min(ntr(i),tlim(1,i))
        tlim(2,i)=max(ntr(i),tlim(2,i))
      enddo
    enddo
  enddo
endif  
tlim(2,:)=tlim(2,:)+1
if (iproc.eq.0) then
  write(*,'("Translation limits:",3(4x,2I4))')tlim(:,1),tlim(:,2),tlim(:,3)
endif

call getufr(lmaxvr,nrfmax,ufr)

allocate(acoeff(lmmaxvr,mtord,natmtot,nstsv,nkpt))
allocate(evec(nmatmax,nstsv,nkpt))
allocate(evecfv(nmatmax,nstfv,nspnfv))
allocate(evecsv(nstsv,nstsv))
allocate(apwalm(ngkmax,apwordmax,lmmaxapw,natmtot))
! read and transform eigen-vectors
do ikloc=1,nkptloc(0)
  do i=0,nproc-1
    if (iproc.eq.i.and.ikloc.le.nkptloc(iproc)) then
      ik=ikptloc(iproc,1)+ikloc-1
      call getevecfv(vkl(1,ik),vgkl(1,1,ikloc,1),evecfv)
      call getevecsv(vkl(1,ik),evecsv)
    endif
#ifdef _MPI_
    call mpi_barrier(MPI_COMM_WORLD,ierr)
#endif
  enddo !i
  if (ikloc.le.nkptloc(iproc)) then
! get a-coeffs 
    call match(ngk(ik,1),gkc(1,ikloc,1),tpgkc(1,1,ikloc,1),sfacgk(1,1,ikloc,1),apwalm)
    call getacoeff(lmaxvr,lmmaxvr,ngk(ik,1),mtord,apwalm,evecfv, &
        evecsv,acoeff(1,1,1,1,ik))
! transform eigen-vectors
    do ispn=1,nspinor
      do j=1,nstfv
        do ig=1,ngk(ik,1)
          zt1=dcmplx(0.d0,0.d0)
          do istfv=1,nstfv
	        zt1=zt1+evecsv(istfv+(ispn-1)*nstfv,j+(ispn-1)*nstfv) * &
	          evecfv(ig,istfv,1)
          enddo
	  evec(ig,j+(ispn-1)*nstfv,ik)=zt1
        enddo !ig
      enddo !j
    enddo !ispn
  endif
enddo
do ik=1,nkpt
  call zsync(acoeff(1,1,1,1,ik),lmmaxvr*mtord*natmtot*nstsv,.true.,.true.)
  call zsync(evec(1,1,ik),nmatmax*nstsv,.true.,.false.)
enddo

allocate(bcoeff(lmmaxvr,mtord,natmtot,wf_dim,tlim(1,1):tlim(2,1),tlim(1,2):tlim(2,2),tlim(1,3):tlim(2,3)))
bcoeff=dcmplx(0.d0,0.d0)

allocate(acoefftmp(lmmaxvr,mtord,natmtot,wf_dim,nkpt))
acoefftmp=dcmplx(0.d0,0.d0)
do n=1,wf_dim
  do ik=1,nkpt
    do i=1,nstfv
      acoefftmp(:,:,:,n,ik)=acoefftmp(:,:,:,n,ik) + &
        wfc(n,i,1,ik)*acoeff(:,:,:,i,ik)
    enddo
  enddo
enddo

do i1=tlim(1,1),tlim(2,1)
do i2=tlim(1,2),tlim(2,2)
do i3=tlim(1,3),tlim(2,3)
  t(:)=i1*avec(:,1)+i2*avec(:,2)+i3*avec(:,3)
  do n=1,wf_dim
    do ik=1,nkpt
      bcoeff(:,:,:,n,i1,i2,i3)=bcoeff(:,:,:,n,i1,i2,i3) + &
        exp(dcmplx(0.d0,dot_product(t,vkc(:,ik)))) * &
        acoefftmp(:,:,:,n,ik)/nkpt
    enddo
  enddo
enddo
enddo
enddo
deallocate(acoefftmp)

allocate(evec1(nmatmax,wf_dim,nkpt))
evec1=dcmplx(0.d0,0.d0)
do n=1,wf_dim
  do ik=1,nkpt
    do i=1,nstfv
      evec1(:,n,ik)=evec1(:,n,ik)+wfc(n,i,1,ik)*evec(:,i,ik)/nkpt
    enddo
  enddo
enddo

if (wf3d) then
  ir=0
  do i1=0,nrxyz(1)-1
    write(*,'("step ",I4," out of ",I4)')i1+1,nrxyz(1)
    do i2=0,nrxyz(2)-1
      do i3=0,nrxyz(3)-1
! arbitrary r-point
        r(:)=orig3d(:)+i1*bound3d(:,1)/nrxyz(1)+ &
                     i2*bound3d(:,2)/nrxyz(2)+ &
                     i3*bound3d(:,3)/nrxyz(3)
        ir=ir+1
        call wann_val(r,wf(:,ir),wf_dim,mtord,ufr,tlim,bcoeff,evec1)
      enddo
    enddo
  enddo
else
  ir=0
  do i1=0,nrxyz(1)-1
    write(*,'("step ",I4," out of ",I4)')i1+1,nrxyz(1)
    do i2=0,nrxyz(2)-1
! arbitrary r-point
      r(:)=orig2d(:)+i1*bound2d(:,1)/nrxyz(1)+ &
                     i2*bound2d(:,2)/nrxyz(2)
      ir=ir+1
      call wann_val(r,wf(:,ir),wf_dim,mtord,ufr,tlim,bcoeff,evec1)
    enddo
  enddo
endif

if (.not.wf3d) then
  x(1)=sqrt(bound2d(1,1)**2+bound2d(2,1)**2+bound2d(3,1)**2)
  x(2)=sqrt(bound2d(1,2)**2+bound2d(2,2)**2+bound2d(3,2)**2)
  alph=dot_product(bound2d(:,1),bound2d(:,2))/x(1)/x(2)
  alph=acos(alph)
endif

do n=1,wf_dim
  write(fname,'("wf_",I2.2,".dx")')n
  open(70,file=fname,status='replace',form='formatted')
  if (wf3d) then
    write(70,400)nrxyz(1),nrxyz(2),nrxyz(3)
    write(70,402)orig3d(:)
    do i=1,3
      write(70,404)bound3d(:,i)/nrxyz(i)
    enddo
    write(70,406)nrxyz(1),nrxyz(2),nrxyz(3)
  else
    write(70,500)nrxyz(1),nrxyz(2)
    write(70,502)(/0.d0, 0.d0/)
    write(70,504)(/x(1),0.d0/)/nrxyz(1)
    write(70,504)(/x(2)*cos(alph),x(2)*sin(alph)/)/nrxyz(2)
    write(70,506)nrxyz(1),nrxyz(2)
  endif
  write(70,408)2,nrtot
  write(70,410)(abs(wf(n,ir)),abs(wf(n,ir))**2,ir=1,nrtot)
  write(70,412)
  close(70)
enddo

      stop
      
  20  format('j:',i3,' dist:',f12.6,' |b|:',16f8.4)
  
 200  format(f6.2,' % complete')

 290  format('# WF_',i1)
 300  format('#   max_v  ', f14.10)
 302  format('#   max_v^2', f14.10)

 400  format('object 1 class gridpositions counts ', 3i4)
 402  format('origin ', 3f12.6)
 404  format('delta ', 3f12.6)
 406  format('object 2 class gridconnections counts ', 3i4)
 408  format('object 3 class array type float rank 1 shape',i3, &
              ' items ',i8,' data follows')
 410  format(f10.6)
 412  format('object "regular positions regular connections" class field', &
            /'component "positions" value 1',   &
	    /'component "connections" value 2', &
	    /'component "data" value 3',        &
	    /'end')

 500  format('object 1 class gridpositions counts ', 2i4)
 502  format('origin ', 2f12.6)
 504  format('delta ', 2f12.6)
 506  format('object 2 class gridconnections counts ', 2i4)







return
end


subroutine wann_val(r,val,wf_dim,mtord,ufr,tlim,bcoeff,evec1)
use modmain
!use modwann
implicit none
! arguments
real(8), intent(in) :: r(3)
integer, intent(in) :: mtord
integer, intent(in) :: wf_dim
real(8), intent(in) :: ufr(nrmtmax,0:lmaxvr,mtord,natmtot)
integer, intent(in) :: tlim(2,3)
complex(8), intent(in) :: bcoeff(lmmaxvr,mtord,natmtot,wf_dim,tlim(1,1):tlim(2,1),tlim(1,2):tlim(2,2),tlim(1,3):tlim(2,3))
complex(8), intent(in) :: evec1(nmatmax,wf_dim,nkpt)
complex(4), intent(out) :: val(wf_dim)

integer ivec,ntr(3),n
real(8) t(3),d,r1(3),pos(3),v1(3),t1,rmt2
complex(8) sum
integer i1,i2,i3,np2,is,ia,ias,ir,ir0,io,l,m,lm,i,j,ig,ik
real(8) ya(nprad),c(nprad),tp(2),t2
complex(8) ylm(lmmaxvr)
real(8), external :: polynom 

! reduce r-point to primitive cell and find corresponding translation vector
do ivec=1,3
  d=dot_product(r,bvec(:,ivec))/twopi
  ntr(ivec)=floor(d)
enddo

t(:)=ntr(1)*avec(:,1)+ntr(2)*avec(:,2)+ntr(3)*avec(:,3)

r1(:)=r(:)-t(:)

np2=nprad/2
val=cmplx(0.0,0.0)

! check if point is in a muffin-tin
do is=1,nspecies
  rmt2=rmt(is)**2
  do ia=1,natoms(is)
    ias=idxas(ia,is)
    do i1=0,1
    do i2=0,1
    do i3=0,1
      pos(:)=atposc(:,ia,is)+i1*avec(:,1)+i2*avec(:,2)+i3*avec(:,3)
      v1(:)=r1(:)-pos(:)
      t1=v1(1)**2+v1(2)**2+v1(3)**2
      if (t1.lt.rmt2) then
        call sphcrd(v1,t1,tp)
        call genylm(lmaxvr,tp,ylm)
        do ir=1,nrmt(is)
          if (spr(ir,is).ge.t1) then
            if (ir.le.np2) then
              ir0=1
            else if (ir.gt.nrmt(is)-np2) then
              ir0=nrmt(is)-nprad+1
            else
              ir0=ir-np2
            end if
            t1=max(t1,spr(1,is))
            sum=0.d0
            do io=1,mtord
              do l=0,lmaxvr
                do m=-l,l
                  lm=idxlm(l,m)
                  do j=1,nprad
                    i=ir0+j-1
                    ya(j)=ufr(i,l,io,ias)
                  end do
                  t2=polynom(0,nprad,spr(ir0,is),ya,c,t1)
                  do n=1,wf_dim
                    val(n)=val(n)+t2*ylm(lm)*bcoeff(lm,io,ias,n,ntr(1)+i1,ntr(2)+i2,ntr(3)+i3)
                  enddo
                end do !m
              end do  !l
            enddo !io
            goto 10
          end if
        end do !ir
      end if
    end do
    end do
    end do
  end do
end do
! otherwise use interstitial function
do ik=1,nkpt
  do ig=1,ngk(ik,1)
    t1=vgkc(1,ig,ik,1)*r(1)+vgkc(2,ig,ik,1)*r(2)+vgkc(3,ig,ik,1)*r(3)
    do n=1,wf_dim
      val(n)=val(n)+cmplx(cos(t1),sin(t1),8)*evec1(ig,n,ik)/sqrt(omega)
    enddo
  end do
end do
10 continue
return
end


subroutine getntr(v,ntr)
use modmain
implicit none
real(8), intent(in) :: v(3)
integer, intent(out) :: ntr(3)
real(8) t
integer ivec

do ivec=1,3
  t=dot_product(v,bvec(:,ivec))/twopi
  ntr(ivec)=floor(t)
enddo

return
end














subroutine putwfc(ik,wfcp)
use modmain
use modwann
implicit none
integer, intent(in) :: ik
complex(8), intent(in) :: wfcp(wf_dim,nstfv,wann_nspins)
integer recl

inquire(iolength=recl)ik,wf_dim,nstfv,wann_nspins,wfcp
open(70,file='WFC.OUT',action='WRITE',form='UNFORMATTED', &
  access='DIRECT',recl=recl)
write(70,rec=ik)ik,wf_dim,nstfv,wann_nspins,wfcp
close(70)

return
end




subroutine getwfc(ik,wfcp)
use modmain
use modwann
implicit none
integer, intent(in) :: ik
complex(8), intent(out) :: wfcp(wf_dim,nstfv,wann_nspins)
integer ik_,wf_dim_,nstfv_,wann_nspins_,recl

inquire(iolength=recl)ik_,wf_dim_,nstfv_,wann_nspins_,wfcp
open(70,file='WFC.OUT',action='READ',form='UNFORMATTED', &
  access='DIRECT',recl=recl)
read(70,rec=ik)ik_,wf_dim_,nstfv_,wann_nspins_,wfcp
close(70)
if (ik_.ne.ik.or.wf_dim_.ne.wf_dim.or.nstfv_.ne.nstfv.or. &
  wann_nspins_.ne.wann_nspins) then
  write(*,*)
  write(*,'("Error(getwfc): wrong dimensions")')
  write(*,*)
  call pstop
endif

return
end



