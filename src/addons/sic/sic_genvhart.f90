subroutine sic_genvhart(vhwanmt,vhwanir)
use modmain
use mod_addons_q
use mod_wannier
use mod_expigqr
use mod_linresp
use mod_sic
implicit none
complex(8), intent(out) :: vhwanmt(lmmaxvr,nmtloc,sic_orbitals%ntr,nspinor,sic_wantran%nwan)
complex(8), intent(out) :: vhwanir(ngrloc,sic_orbitals%ntr,nspinor,sic_wantran%nwan)
integer nvqloc,iqloc,it,iq,n,ig,ias,i,j
complex(8), allocatable :: pwmt(:,:)
complex(8), allocatable :: pwir(:)
complex(8), allocatable ::megqwan1(:,:,:)
complex(8) expikt,zt1
character*100 qnm

integer ntp,itp,lm,ia,is,ir
real(8), allocatable :: fmt(:,:,:)
real(8), allocatable :: fmt_(:,:,:)
complex(8), allocatable :: zfmt(:,:,:)
complex(8), allocatable :: zfir(:)
real(8), allocatable :: tp(:,:)
real(8), allocatable :: rlmb(:,:)
real(8), allocatable :: wtp(:)
real(8), allocatable :: spx(:,:)
real(8) rlm(lmmaxvr),vrc(3),t1

vhwanmt=zzero
vhwanir=zzero

#ifdef _MAD_
allocate(fmt(lmmaxvr,nrmtmax,natmtot))
allocate(zfmt(lmmaxvr,nrmtmax,natmtot))
allocate(zfir(ngrtot))

ntp=266
allocate(tp(2,ntp))
allocate(rlmb(ntp,lmmaxvr))
allocate(wtp(ntp))
! Lebedev mesh
allocate(spx(3,ntp))
call leblaik(ntp,spx,wtp)                                                                   
do itp=1,ntp                   
  wtp(itp)=wtp(itp)*fourpi
  call sphcrd(spx(:,itp),t1,tp(:, itp))                                                     
enddo 
! generate spherical harmonics
do itp=1,ntp 
  call genrlm(lmaxvr,tp(1,itp),rlm)  
  do lm=1,lmmaxvr
    rlmb(itp,lm)=rlm(lm)*wtp(itp)
  enddo
enddo
deallocate(wtp,tp)

allocate(fmt_(ntp,nrmtmax,natmtot))
do j=1,sic_wantran%nwan
  n=sic_wantran%iwan(j)
  call elk_load_wann_unk(n)
  call madness_gen_hpot(n)
  
  do it=1,sic_orbitals%ntr
    fmt_=0.d0
    do ias=1,natmtot
      is=ias2is(ias)
      ia=ias2ia(ias)
      do ir=1,nrmt(is)
        do itp=1,ntp
          vrc(:)=spx(:,itp)*spr(ir,is)+atposc(:,ia,is)+sic_orbitals%vtc(:,it)
          call madness_get_hpot(vrc,fmt_(itp,ir,ias))
        enddo
      enddo !ir
    enddo !ias
    call dgemm('T','N',lmmaxvr,nrmtmax*natmtot,ntp,1.d0,rlmb,ntp,fmt_,ntp,0.d0,&
      fmt,lmmaxvr)
    zfmt=dcmplx(fmt,0.d0)
    call sic_copy_mt_z(.true.,lmmaxvr,zfmt,vhwanmt(1,1,it,1,j))
    do ir=1,ngrtot
      vrc(:)=vgrc(:,ir)+sic_orbitals%vtc(:,it)
      call madness_get_hpot(vrc,t1)
      zfir(ir)=dcmplx(t1,0.d0)
    enddo
    call sic_copy_ir_z(.true.,zfir,vhwanir(1,it,1,j))
  enddo !it
enddo !j
deallocate(fmt_,fmt,zfmt,zfir,spx,rlmb)
  

#else
call init_qbz(tq0bz,1)
call init_q_gq
! create q-directories
if (mpi_grid_root()) then
  call system("mkdir -p q")
  do iq=1,nvq
    call getqdir(iq,vqm(:,iq),qnm)
    call system("mkdir -p "//trim(qnm))
  enddo
endif
call mpi_grid_barrier()
wannier_megq=.true.
megq_include_bands(:)=(/100.1d0,-100.1d0/)
call deletewantran(megqwantran)
call genwantran(megqwantran,-0.d0,0.01d0,diagwt=.true.)
allocate(megqwan1(sic_wantran%nwan,ngqmax,nvq))
megqwan1=zzero
! distribute q-vectors along 2-nd dimention
nvqloc=mpi_grid_map(nvq,dim_q)
call timer_start(10,reset=.true.)
! loop over q-points
do iqloc=1,nvqloc
  iq=mpi_grid_map(nvq,dim_q,loc=iqloc)
  call genmegq(iq,.true.,.false.)
! save <n,T=0|e^{-i(G+q)r}|n,T=0>
  do j=1,sic_wantran%nwan
    n=sic_wantran%iwan(j)
    megqwan1(j,1:ngq(iq),iq)=megqwan(megqwantran%iwtidx(n,n,0,0,0),1:ngq(iq))
  enddo
enddo
call mpi_grid_reduce(megqwan1(1,1,1),sic_wantran%nwan*ngqmax*nvq,&
  dims=(/dim_q/),all=.true.)
call timer_stop(10)
! allocate arrays for plane-wave
allocate(pwmt(lmmaxvr,nmtloc))
allocate(pwir(ngrloc))
! generate Hartree potential
call timer_start(11,reset=.true.)
do iq=1,nvq
  do ig=1,ngq(iq)
    call sic_genpw(vgqc(1,ig,iq),pwmt,pwir)
    do it=1,sic_orbitals%ntr
      expikt=exp(zi*dot_product(sic_orbitals%vtc(:,it),vqc(:,iq)))/nkptnr/omega
      do j=1,sic_wantran%nwan
        n=sic_wantran%iwan(j)
        if (sic_apply(n).eq.2) then
          zt1=megqwan1(j,ig,iq)*vhgq(ig,iq)*expikt
          do i=1,nmtloc
            ias=(mtoffs+i-1)/nrmtmax+1
            if (sic_orbitals%twanmt(ias,it,n)) then       
              call zaxpy(lmmaxvr,zt1,pwmt(1,i),1,vhwanmt(1,i,it,1,j),1)
            endif
          enddo
          call zaxpy(ngrloc,zt1,pwir,1,vhwanir(1,it,1,j),1)
        endif !sic_apply(n).eq.2
      enddo !n
    enddo !it
  enddo !ig
enddo !iq
call timer_stop(11)
deallocate(pwmt,pwir,megqwan1)
#endif
return
end
