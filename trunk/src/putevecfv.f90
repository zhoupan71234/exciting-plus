
! Copyright (C) 2007 J. K. Dewhurst, S. Sharma and C. Ambrosch-Draxl.
! This file is distributed under the terms of the GNU General Public License.
! See the file COPYING for license details.

subroutine putevecfv(ik,evecfv)
use modmain
use mod_mpi_grid
implicit none
! arguments
integer, intent(in) :: ik
complex(8), intent(in) :: evecfv(nmatmax,nstfv,nspnfv)
integer :: ikloc
! local variables
integer recl
ikloc=mpi_grid_map(nkpt,dim_k,glob=ik)
! find the record length
inquire(iolength=recl) vkl(:,ik),nmatmax,nstfv,nspnfv,evecfv,vgkl(:,:,1,ikloc),&
  igkig(:,:,ikloc)
open(70,file=trim(scrpath)//'EVECFV'//trim(filext),action='WRITE', &
 form='UNFORMATTED',access='DIRECT',recl=recl)
write(70,rec=ik) vkl(:,ik),nmatmax,nstfv,nspnfv,evecfv,vgkl(:,:,1,ikloc),&
  igkig(:,:,ikloc)
close(70)
return
end subroutine

