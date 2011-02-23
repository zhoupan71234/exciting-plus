subroutine sic_test_blochsum
use modmain
use mod_sic
implicit none
integer ik,ikloc,j,n,jas,it,ias,is,ir,itp,ispn,ntrloc,itloc,lm
real(8) x(3),t1
real(8), allocatable :: tp(:,:)
complex(8), allocatable :: zprod(:,:,:)
complex(8) zt1,zt2,expikt,wanval(nspinor)
complex(8), external :: zfinp_
complex(8), allocatable :: wfmt(:,:)
complex(8), allocatable :: wftp(:,:,:)
complex(8), allocatable :: wflm(:,:,:)
!
s_wankmt=zzero
s_wankir=zzero
s_wvkmt=zzero
s_wvkir=zzero


allocate(zprod(2,sic_wantran%nwan,nkpt))
allocate(wfmt(lmmaxvr,nrmtmax))
allocate(wftp(s_ntp,nrmtmax,nspinor))
!allocate(wftp(lmmaxvr,nrmtmax,nspinor))
allocate(wflm(lmmaxvr,nrmtmax,nspinor))


zprod=zzero
allocate(tp(2,lmmaxvr))
call sphcover(lmmaxvr,tp)

ntrloc=mpi_grid_map(sic_orbitals%ntr,dim2)
do ikloc=1,1 !nkptloc
  ik=mpi_grid_map(nkpt,dim_k,loc=ikloc)
! make Bloch sums
  do j=1,sic_wantran%nwan
    n=sic_wantran%iwan(j)
    jas=wan_info(1,n)
    do ias=1,natmtot
      is=ias2is(ias)
      wftp=zzero
      do itloc=1,ntrloc
        it=mpi_grid_map(sic_orbitals%ntr,dim2,loc=itloc)
        expikt=exp(-zi*dot_product(vkc(:,ik),sic_orbitals%vtc(:,it)))
! muffin-tins
!        do ir=1,nrmt(is)
!          do itp=1,lmmaxvr
!            x(:)=(/sin(tp(1,itp))*cos(tp(2,itp)),&
!                   sin(tp(1,itp))*sin(tp(2,itp)),&
!                   cos(tp(1,itp))/)*spr(ir,is)+&
!                   atposc(:,ias2ia(ias),ias2is(ias))+sic_orbitals%vtc(:,it)
!            call s_get_wanval(n,x,wanval)
!            wftp(itp,ir,:)=wftp(itp,ir,:)+wanval(:)*expikt
!          enddo !itp
!        enddo !ir
        do ir=1,nrmt(is)
          do itp=1,s_ntp
            x(:)=s_spx(:,itp)*spr(ir,is)+atposc(:,ias2ia(ias),ias2is(ias))+&
                 sic_orbitals%vtc(:,it) !-atposc(:,ias2ia(jas),ias2is(jas))
            do ispn=1,nspinor
              !wftp(itp,ir,ispn)=wftp(itp,ir,ispn)+expikt*s_func_val(x,s_wanlm(1,1,ispn,j)) 
              call s_get_wanval(n,x,wanval)
              wftp(itp,ir,:)=wftp(itp,ir,:)+wanval(:)*expikt
              !s_wankmt(itp,ir,ias,ispn,j,ikloc)=s_wankmt(itp,ir,ias,ispn,j,ikloc)+&
              !  expikt*s_func_val(x,s_wanlm(1,1,ispn,j))
              !s_wvkmt(itp,ir,ias,ispn,j,ikloc)=s_wvkmt(itp,ir,ias,ispn,j,ikloc)+&
              !  expikt*s_func_val(x,s_wvlm(1,1,ispn,j))
            enddo
          enddo !itp
        enddo !ir
      enddo !itloc
 ! convert to spherical harmonics
      do ispn=1,nspinor
        call zgemm('T','N',lmmaxvr,nrmt(is),s_ntp,zone,s_ylmb,s_ntp,&
          wftp(1,1,ispn),s_ntp,zzero,wflm(1,1,ispn),lmmaxvr)
          s_wankmt(:,:,ias,ispn,j,ikloc)=wflm(:,:,ispn)
      enddo !ispn
      !do ispn=1,nspinor
      !  call zgemm('N','N',lmmaxvr,nrmt(is),lmmaxvr,zone,zfshtvr,lmmaxvr, &
      !    wftp(1,1,ispn),lmmaxvr,zzero,s_wankmt(1,1,ias,ispn,j,ikloc),lmmaxvr)
      !enddo
    enddo !ias
! interstitial
    do itloc=1,ntrloc
      it=mpi_grid_map(sic_orbitals%ntr,dim2,loc=itloc)
      expikt=exp(-zi*dot_product(vkc(:,ik),sic_orbitals%vtc(:,it)))
      do ir=1,ngrtot
        x(:)=vgrc(:,ir)+sic_orbitals%vtc(:,it)
        call s_get_wanval(n,x,wanval)
        s_wankir(ir,:,j,ikloc)=s_wankir(ir,:,j,ikloc)+wanval(:)*expikt
        !x(:)=vgrc(:,ir)+sic_orbitals%vtc(:,it)-atposc(:,ias2ia(jas),ias2is(jas))
        !do ispn=1,nspinor
        !  s_wankir(ir,ispn,j,ikloc)=s_wankir(ir,ispn,j,ikloc)+&
        !    s_func_val(x,s_wanlm(1,1,ispn,j))*expikt 
        !  s_wvkir(ir,ispn,j,ikloc)=s_wvkir(ir,ispn,j,ikloc)+&
        !    s_func_val(x,s_wvlm(1,1,ispn,j))*expikt 
        !enddo
      enddo
    enddo !itloc
    call mpi_grid_reduce(s_wankmt(1,1,1,1,j,ikloc),&
      lmmaxvr*nrmtmax*natmtot*nspinor,dims=(/dim2/),all=.true.)
    call mpi_grid_reduce(s_wankir(1,1,j,ikloc),ngrtot*nspinor,&
      dims=(/dim2/),all=.true.)
    call mpi_grid_reduce(s_wvkmt(1,1,1,1,j,ikloc),&
      lmmaxvr*nrmtmax*natmtot*nspinor,dims=(/dim2/),all=.true.)
    call mpi_grid_reduce(s_wvkir(1,1,j,ikloc),ngrtot*nspinor,&
      dims=(/dim2/),all=.true.)
!    do ispn=1,nspinor
!      do ias=1,natmtot
!        call zgemm('N','N',lmmaxvr,nrmt(ias2is(ias)),lmmaxvr,zone,&
!          zfshtvr,lmmaxvr,s_wankmt(1,1,ias,ispn,j,ikloc),lmmaxvr,&
!          zzero,wfmt,lmmaxvr)
!        s_wankmt(:,:,ias,ispn,j,ikloc)=wfmt
!      enddo
!    enddo
    if (mpi_grid_root((/dim2/)).and.ik.eq.1.and.j.eq.1) then
      open(220,file="re_wnkmt.dat",form="formatted",status="replace")
      open(221,file="im_wnkmt.dat",form="formatted",status="replace")
      do lm=1,lmmaxvr
        do ir=1,nrmt(1)
          write(220,'(2G18.10)')spr(ir,1),dreal(s_wankmt(lm,ir,1,1,1,1)) 
          write(221,'(2G18.10)')spr(ir,1),dimag(s_wankmt(lm,ir,1,1,1,1)) 
        enddo
        write(220,*)
        write(221,*)
      enddo
      close(220)
      close(221)
    endif 
 
    zt1=zzero
    zt2=zzero
    do ispn=1,nspinor
      zt1=zt1+zfinp_(s_wankmt(1,1,1,ispn,j,ikloc),s_wankmt(1,1,1,ispn,j,ikloc),&
        s_wankir(1,ispn,j,ikloc),s_wankir(1,ispn,j,ikloc))
      zt2=zt2+zfinp_(s_wvkmt(1,1,1,ispn,j,ikloc),s_wankmt(1,1,1,ispn,j,ikloc),&
        s_wvkir(1,ispn,j,ikloc),s_wankir(1,ispn,j,ikloc))
    enddo
    zprod(1,j,ik)=zt1
    zprod(2,j,ik)=zt2
  enddo !j
enddo !ikloc 
call mpi_grid_reduce(zprod(1,1,1),2*sic_wantran%nwan*nkpt,dims=(/dim_k/))
if (mpi_grid_root()) then
  open(210,file="SIC_BLOCHSUM.OUT",form="formatted",status="replace")
  do ik=1,nkpt
    write(210,'(" ik : ",I4)')ik
    do j=1,sic_wantran%nwan
      n=sic_wantran%iwan(j)
      write(210,'("  n : ",I4,6X," <W_nk|W_nk> : ",2G18.10)')&
        n,dreal(zprod(1,j,ik)),dimag(zprod(1,j,ik))
    enddo
    write(210,*)
  enddo !ik
  close(210)
endif
deallocate(tp)
deallocate(zprod)
return
end
