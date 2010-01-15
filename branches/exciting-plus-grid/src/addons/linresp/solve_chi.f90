subroutine solve_chi(igq0,vcgq,chi0m,krnl,chi_,epsilon_,krnl_scr)
use modmain
implicit none
integer, intent(in) :: igq0
real(8), intent(in) :: vcgq(ngvecchi)
complex(8), intent(in) :: chi0m(ngvecchi,ngvecchi)
complex(8), intent(inout) :: krnl(ngvecchi,ngvecchi)
complex(8), intent(out) :: chi_(4)
complex(8), intent(out) :: epsilon_(5)
complex(8), intent(out) :: krnl_scr(ngvecchi,ngvecchi)
! local variables
complex(8), allocatable :: epsilon(:,:)
complex(8), allocatable :: mtrx1(:,:)
complex(8), allocatable :: zm1(:,:),zm2(:,:)
real(8) d1
integer i,ig1,ig2

! Note: different epsilons and chis are introdued only to go inside the 
!   "black box" of non-linear marix equation for chi
! functions that are related to physical measurements are: 
!   1. chi_{Gq,Gq}(q-Gq,w) 
!   2. epsilon_eff(q-Gq,w)

! construct full kernel
if (lrtype.eq.0) then
  do i=1,ngvecchi
    krnl(i,i)=krnl(i,i)+vcgq(i)**2
  enddo
endif

allocate(epsilon(ngvecchi,ngvecchi))
allocate(mtrx1(ngvecchi,ngvecchi))
allocate(zm1(ngvecchi,ngvecchi))
allocate(zm2(ngvecchi,ngvecchi))

! save chi0
chi_(1)=chi0m(igq0,igq0)
! compute matrix 1-chi0*(v+fxc) 
epsilon=dcmplx(0.d0,0.d0)
do i=1,ngvecchi
  epsilon(i,i)=dcmplx(1.d0,0.d0)
enddo
call zgemm('N','N',ngvecchi,ngvecchi,ngvecchi,dcmplx(-1.d0,0.d0), &
  chi0m,ngvecchi,krnl,ngvecchi,dcmplx(1.d0,0.d0),epsilon,ngvecchi)
!call wrmtrx('epsilon.txt',ngvecchi,epsilon)
! save epsilon_matrix_GqGq
epsilon_(1)=epsilon(igq0,igq0)
! save epsilon_scalar_GqGq
epsilon_(2)=1.d0-chi0m(igq0,igq0)*krnl(igq0,igq0)
! invert epsilon matrix
call invzge(epsilon,ngvecchi)
!call wrmtrx('epsilon_inv.txt',ngvecchi,epsilon)
! save 1/(epsilon^-1)_{GqGq}
epsilon_(3)=1.d0/epsilon(igq0,igq0)
! save chi_scalar
chi_(2)=chi0m(igq0,igq0)/epsilon_(2)
! save chi_pseudo_scalar
chi_(3)=chi0m(igq0,igq0)/epsilon_(3)
! compute chi=epsilon^-1 * chi0
call zgemm('N','N',ngvecchi,ngvecchi,ngvecchi,dcmplx(1.d0,0.d0), &
  epsilon,ngvecchi,chi0m,ngvecchi,dcmplx(0.d0,0.d0),mtrx1,ngvecchi)
!call wrmtrx('chi.txt',ngvecchi,mtrx1)
! save chi
chi_(4)=mtrx1(igq0,igq0)
! save epsilon_eff
epsilon_(4)=1.d0/(1.d0+(vcgq(igq0)**2)*chi_(4))
! save epsilon_eff_scalar
epsilon_(5)=1.d0/(1.d0+(vcgq(igq0)**2)*chi_(2))

if (screened_w) then
! compute screened Coulomb potential: vscr=vbare+vbare*chi*vbare
  krnl_scr=krnl
! compute zm2=chi*v
  call zgemm('N','N',ngvecchi,ngvecchi,ngvecchi,dcmplx(1.d0,0.d0), &
    mtrx1,ngvecchi,krnl,ngvecchi,dcmplx(0.d0,0.d0),zm2,ngvecchi)
! compute krnl_scr=v*zm2
  call zgemm('N','N',ngvecchi,ngvecchi,ngvecchi,dcmplx(1.d0,0.d0), &
    krnl,ngvecchi,zm2,ngvecchi,dcmplx(1.d0,0.d0),krnl_scr,ngvecchi)
! compute screened Coulomb potential using "symmetrized" dielectric function
  do ig1=1,ngvecchi
    do ig2=1,ngvecchi
      epsilon(ig1,ig2)=-vcgq(ig1)*chi0m(ig1,ig2)*vcgq(ig2)
    enddo
    epsilon(ig1,ig1)=dcmplx(1.d0,0.d0)+epsilon(ig1,ig1)
  enddo
  call invzge(epsilon,ngvecchi)
  do ig1=1,ngvecchi
    do ig2=1,ngvecchi
      zm1(ig1,ig2)=vcgq(ig1)*epsilon(ig1,ig2)*vcgq(ig2)
    enddo
  enddo
! compute difference
  d1=0.d0
  do ig1=1,ngvecchi
    do ig2=1,ngvecchi
      d1=d1+abs(krnl_scr(ig1,ig2)-zm1(ig1,ig2))
    enddo
  enddo
  if (d1.gt.1d-6) then
    write(*,*)
    write(*,'("Error(solve_chi): screened kernels must be identical")')
    write(*,'("  difference : ",G18.10)')d1
    call pstop
  endif
endif
deallocate(epsilon,mtrx1,zm1,zm2)
return
end

subroutine wrmtrx(name,size,mtrx)
implicit none
character*(*), intent(in) :: name
integer, intent(in) :: size
complex(8), intent(in) :: mtrx(size,size)
integer i,j
open(153,file=trim(adjustl(name)),form='formatted',status='replace')
write(153,'("real part : ")')
do i=1,size
  write(153,'(255F8.3)')(dreal(mtrx(i,j)),j=1,size)
enddo
write(153,'("imag part : ")')
do i=1,size
  write(153,'(255F8.3)')(dimag(mtrx(i,j)),j=1,size)
enddo
close(153)
return
end
