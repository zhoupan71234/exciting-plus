subroutine sic_genvxc(exc)
use modmain
use mod_lf
use modxcifc
implicit none
complex(8), intent(out) :: exc(nwann)
integer ntp,itp,lm,n,itloc,ias,iasloc,natmtotloc,ispn
real(8), allocatable :: tp(:,:)
complex(8), allocatable :: ylm(:,:)
complex(8), allocatable :: ylmc(:,:)
complex(8), allocatable :: vxcwanmt(:,:,:,:,:)
complex(8), allocatable :: vxcwanir(:,:,:)
complex(8), allocatable :: excwanmt(:,:,:,:,:)
complex(8), allocatable :: excwanir(:,:,:)
complex(8), allocatable :: wfmt(:,:)
real(8), allocatable :: wfmt2(:,:,:)
real(8), allocatable :: wfir2(:,:)
real(8), allocatable :: exmt_(:,:)
real(8), allocatable :: exir_(:)
real(8), allocatable :: ecmt_(:,:)
real(8), allocatable :: ecir_(:)
real(8), allocatable :: vxmt_(:,:,:)
real(8), allocatable :: vxir_(:,:)
real(8), allocatable :: vcmt_(:,:,:)
real(8), allocatable :: vcir_(:,:)
complex(8), allocatable :: zvxcmt(:,:,:)
complex(8), allocatable :: zexcmt(:,:)
real(8), external :: gaunt

! XC part of Wannier function potential
allocate(vxcwanmt(lmmaxvr,nrmtmax,natmtot,ntrloc,nspinor))
allocate(vxcwanir(ngrtot,ntrloc,nspinor))
! XC energy density of Wannier function
allocate(excwanmt(lmmaxvr,nrmtmax,natmtot,ntrloc,nspinor))
allocate(excwanir(ngrtot,ntrloc,nspinor))

! make dens mesh of (theta,phi) points on the sphere
ntp=1000
allocate(tp(2,ntp))
allocate(ylm(lmmaxvr,ntp))
allocate(ylmc(ntp,lmmaxvr))
call sphcover(ntp,tp)
do itp=1,ntp 
  call genylm(lmaxvr,tp(1,itp),ylm(1,itp))
  do lm=1,lmmaxvr
    ylmc(itp,lm)=dconjg(ylm(lm,itp))*fourpi/ntp
  enddo
enddo
allocate(wfmt(ntp,nrmtmax))
allocate(wfmt2(ntp,nrmtmax,nspinor))
allocate(wfir2(ngrtot,nspinor))
allocate(exmt_(ntp,nrmtmax))
allocate(exir_(ngrtot))
allocate(ecmt_(ntp,nrmtmax))
allocate(ecir_(ngrtot))
allocate(zexcmt(ntp,nrmtmax))
allocate(vxmt_(ntp,nrmtmax,nspinor))
allocate(vxir_(ngrtot,nspinor))
allocate(vcmt_(ntp,nrmtmax,nspinor))
allocate(vcir_(ngrtot,nspinor))
allocate(zvxcmt(ntp,nrmtmax,nspinor))
do n=1,nwann
  vxcwanmt=zzero
  vxcwanir=zzero
  excwanmt=zzero
  excwanir=zzero
  do itloc=1,ntrloc
!-----------------!
! muffin-tin part !
!-----------------!
    natmtotloc=mpi_grid_map(natmtot,dim_k)
    do iasloc=1,natmtotloc
      wfmt=zzero
      ias=mpi_grid_map(natmtot,dim_k,loc=iasloc)
! compute charge density on a sphere
!   rho(tp,r)=|wf(tp,r)|^2
!   wf(tp,r)=\sum_{lm} R_{lm}(r) * Y_{lm}(tp)
      do ispn=1,nspinor
        call zgemm('T','N',ntp,nrmt(ias2is(ias)),lmmaxvr,zone,ylm,lmmaxvr,&
          wanmt(1,1,ias,itloc,ispn,n),lmmaxvr,zzero,wfmt,ntp)
        wfmt2(:,:,ispn)=dreal(dconjg(wfmt(:,:))*wfmt(:,:))
      enddo
! compute XC potential and energy density
      if (spinpol) then
        call xcifc(xctype,n=ntp*nrmtmax,rhoup=wfmt2(1,1,1),rhodn=wfmt2(1,1,2),&
          ex=exmt_,ec=ecmt_,vxup=vxmt_(1,1,1),vxdn=vxmt_(1,1,2),vcup=vcmt_(1,1,1),&
          vcdn=vcmt_(1,1,2))
     else
        call xcifc(xctype,n=ntp*nrmtmax,rho=wfmt2,ex=exmt_,ec=ecmt_,vx=vxmt_,vc=vcmt_)
      endif
! save XC potential
      do ispn=1,nspinor
        zvxcmt(:,:,ispn)=dcmplx(vxmt_(:,:,ispn)+vcmt_(:,:,ispn),0.d0)
      enddo
! save XC energy
      zexcmt(:,:)=dcmplx(exmt_(:,:)+ecmt_(:,:),0.d0)
! expand XC potential in spherical harmonics
!     R_lm(r)= 4Pi/ntp \sum_{tp}Y_{lm}^{*}(tp) * f(tp,r)   
      do ispn=1,nspinor
        call zgemm('T','N',lmmaxvr,nrmt(ias2is(ias)),ntp,zone,ylmc,ntp,&
          zvxcmt(1,1,ispn),ntp,zzero,vxcwanmt(1,1,ias,itloc,ispn),lmmaxvr)
      enddo
! expand XC energy in spherical harmonics
      call zgemm('T','N',lmmaxvr,nrmt(ias2is(ias)),ntp,zone,ylmc,ntp,&
        zexcmt,ntp,zzero,excwanmt(1,1,ias,itloc,1),lmmaxvr)
    enddo !iasloc
    do ispn=1,nspinor
      call mpi_grid_reduce(vxcwanmt(1,1,1,itloc,ispn),lmmaxvr*nrmtmax*natmtot,&
        dims=(/dim_k/),all=.true.)
    enddo
    call mpi_grid_reduce(excwanmt(1,1,1,itloc,1),lmmaxvr*nrmtmax*natmtot,&
      dims=(/dim_k/),all=.true.)
    if (spinpol) excwanmt(:,:,:,itloc,2)=excwanmt(:,:,:,itloc,1)
!-------------------!
! interstitial part !
!-------------------!
    do ispn=1,nspinor
      wfir2(:,ispn)=dreal(dconjg(wanir(:,itloc,ispn,n))*wanir(:,itloc,ispn,n))
    enddo
    if (spinpol) then
      call xcifc(xctype,n=ngrtot,rhoup=wfir2(:,1),rhodn=wfir2(:,2),ex=exir_,&
        ec=ecir_,vxup=vxir_(:,1),vxdn=vxir_(:,2),vcup=vcir_(:,1),vcdn=vcir_(:,2))
    else
      call xcifc(xctype,n=ngrtot,rho=wfir2,ex=exir_,ec=ecir_,vx=vxir_,vc=vcir_)
    endif
    do ispn=1,nspinor
      vxcwanir(:,itloc,ispn)=dcmplx(vxir_(:,ispn)+vcir_(:,ispn),0.d0)
    enddo
    excwanir(:,itloc,1)=dcmplx(exir_(:)+ecir_(:),0.d0)
    if (spinpol) excwanir(:,itloc,2)=excwanir(:,itloc,1)
  enddo !itloc
  do ispn=1,nspinor
    call lf_prod(-zone,vxcwanmt(1,1,1,1,ispn),vxcwanir(1,1,ispn),&
      wanmt(1,1,1,1,ispn,n),wanir(1,1,ispn,n),zone,&
      vwanmt(1,1,1,1,ispn,n),vwanir(1,1,ispn,n))
    call lf_prod(zone,excwanmt(1,1,1,1,ispn),excwanir(1,1,ispn),&
      wanmt(1,1,1,1,ispn,n),wanir(1,1,ispn,n),zzero,&
      excwanmt(1,1,1,1,ispn),excwanir(1,1,ispn))  
  enddo  
  do ispn=1,nspinor
    exc(n)=exc(n)+lf_dotlf(.true.,(/0,0,0/),excwanmt(1,1,1,1,ispn),&
      excwanir(1,1,ispn),wanmt(1,1,1,1,ispn,n),wanir(1,1,ispn,n))
  enddo
enddo
deallocate(tp)
deallocate(ylm)
deallocate(ylmc)
deallocate(wfmt)
deallocate(wfmt2)
deallocate(wfir2)
deallocate(exmt_)
deallocate(exir_)
deallocate(ecmt_)
deallocate(ecir_)
deallocate(zexcmt)
deallocate(vxmt_)
deallocate(vxir_)
deallocate(vcmt_)
deallocate(vcir_)
deallocate(zvxcmt)
deallocate(vxcwanmt)
deallocate(vxcwanir)
deallocate(excwanmt)
deallocate(excwanir)
return
end