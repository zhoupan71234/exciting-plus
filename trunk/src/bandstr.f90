
! Copyright (C) 2002-2005 J. K. Dewhurst, S. Sharma and C. Ambrosch-Draxl.
! This file is distributed under the terms of the GNU General Public License.
! See the file COPYING for license details.

!BOP
! !ROUTINE: bandstr
! !INTERFACE:
subroutine bandstr
! !USES:
use modmain
use modwann
! !DESCRIPTION:
!   Produces a band structure along the path in reciprocal-space which connects
!   the vertices in the array {\tt vvlp1d}. The band structure is obtained from
!   the second-variational eigenvalues and is written to the file {\tt BAND.OUT}
!   with the Fermi energy set to zero. If required, band structures are plotted
!   to files {\tt BAND\_Sss\_Aaaaa.OUT} for atom {\tt aaaa} of species {\tt ss},
!   which include the band characters for each $l$ component of that atom in
!   columns 4 onwards. Column 3 contains the sum over $l$ of the characters.
!   Vertex location lines are written to {\tt BANDLINES.OUT}. See routine
!   {\tt bandchar}.
!
! !REVISION HISTORY:
!   Created June 2003 (JKD)
!EOP
!BOC
implicit none
! local variables
integer lmax,lmmax,l,m,lm
integer ik,ispn,is,ia,ias,iv,ist
real(8) emin,emax,sum
character(256) fname
! allocatable arrays
real(8), allocatable :: evalfv(:,:)
real(4), allocatable :: bndchr(:,:,:,:,:)
real(8), allocatable :: elmsym(:,:)
real(8), allocatable :: e(:,:)
! low precision for band character array saves memory
real(4), allocatable :: bc(:,:,:,:)
complex(8), allocatable :: evecfv(:,:,:)
complex(8), allocatable :: evecsv(:,:)
real(8), allocatable :: uu(:,:,:,:)
real(8), allocatable :: ufr(:,:,:,:)
integer mtord
! initialise universal variables
call init0
call init1
if (wannier) then
  call wann_init
endif
! allocate array for storing the eigenvalues
allocate(e(nstsv,nkpt))
! maximum angular momentum for band character
lmax=min(3,lmaxapw)
lmmax=(lmax+1)**2
! allocate band character array if required
if (task.eq.21) then
  allocate(bc(0:lmax,natmtot,nstsv,nkpt))
  allocate(bndchr(lmmax,natmtot,nspinor,nstsv,nkpt))
end if
! read density and potentials from file
call readstate
! read Fermi energy from file
call readfermi
! find the new linearisation energies
call linengy
! generate the APW radial functions
call genapwfr
! generate the local-orbital radial functions
call genlofr
! compute the overlap radial integrals
call olprad
! compute the Hamiltonian radial integrals
call hmlrad

if (task.eq.21.or.wannier) then
  call getmtord(lmax,mtord)
  allocate(ufr(nrmtmax,0:lmax,mtord,natmtot))
  call getufr(lmax,mtord,ufr)
  allocate(uu(0:lmax,mtord,mtord,natmtot))
  call calc_uu(lmax,mtord,ufr,uu)
endif

emin=1.d5
emax=-1.d5
! begin parallel loop over k-points
!$OMP PARALLEL DEFAULT(SHARED) &
!$OMP PRIVATE(evalfv,evecfv,evecsv) &
!$OMP PRIVATE(elmsym) &
!$OMP PRIVATE(ispn,ist,is,ia,ias,l,m,lm,sum)
!$OMP DO
do ik=1,nkpt
  allocate(evalfv(nstfv,nspnfv))
  allocate(evecfv(nmatmax,nstfv,nspnfv))
  allocate(evecsv(nstsv,nstsv))
  if (task.eq.21) then
    allocate(elmsym(lmmax,natmtot))
  end if
!$OMP CRITICAL
  write(*,'("Info(bandstr): ",I6," of ",I6," k-points")') ik,nkpt
!$OMP END CRITICAL
! solve the first- and second-variational secular equations
  call seceqn(ik,evalfv,evecfv,evecsv)
  if (wannier) then
    call wann_a_ort(ik,mtord,uu,evecfv,evecsv)
  endif
  do ist=1,nstsv
! subtract the Fermi energy
    e(ist,ik)=evalsv(ist,ik)-efermi
! add scissors correction
    if (e(ist,ik).gt.0.d0) e(ist,ik)=e(ist,ik)+scissor
    emin=min(emin,e(ist,ik))
    emax=max(emax,e(ist,ik))
  end do
! compute the band characters if required
  if (task.eq.21) then
    call bandchar(.false.,lmax,ik,mtord,evecfv,evecsv,lmmax,bndchr(1,1,1,1,ik),uu)
! average band character over spin and m for all atoms
    do is=1,nspecies
      do ia=1,natoms(is)
        ias=idxas(ia,is)
        do ist=1,nstsv
          do l=0,lmax
            sum=0.d0
            do m=-l,l
              lm=idxlm(l,m)
              do ispn=1,nspinor
                sum=sum+bndchr(lm,ias,ispn,ist,ik)
              end do
            end do
            bc(l,ias,ist,ik)=real(sum)
          end do
        end do
      end do
    end do
  end if
  deallocate(evalfv,evecfv,evecsv)
  if (task.eq.21) then
    deallocate(elmsym)
  end if
! end loop over k-points
end do
!$OMP END DO
!$OMP END PARALLEL
emax=emax+(emax-emin)*0.5d0
emin=emin-(emax-emin)*0.5d0
! output the band structure
if (task.eq.20) then
  open(50,file='BAND.OUT',action='WRITE',form='FORMATTED')
  do ist=1,nstsv
    do ik=1,nkpt
      write(50,'(2G18.10)') dpp1d(ik),e(ist,ik)
    end do
    write(50,'("     ")')
  end do
  close(50)
  write(*,*)
  write(*,'("Info(bandstr):")')
  write(*,'(" band structure plot written to BAND.OUT")')
else
  do is=1,nspecies
    do ia=1,natoms(is)
      ias=idxas(ia,is)
      write(fname,'("BAND_S",I2.2,"_A",I4.4,".OUT")') is,ia
      open(50,file=trim(fname),action='WRITE',form='FORMATTED')
      do ist=1,nstsv
        do ik=1,nkpt
! sum band character over l
          sum=0.d0
          do l=0,lmax
            sum=sum+bc(l,ias,ist,ik)
          end do
          write(50,'(2G18.10,8F12.6)') dpp1d(ik),e(ist,ik),sum, &
           (bc(l,ias,ist,ik),l=0,lmax)
        end do
        write(50,'("     ")')
      end do
      close(50)
    end do
  end do
  write(*,*)
  write(*,'("Info(bandstr):")')
  write(*,'(" band structure plot written to BAND_Sss_Aaaaa.OUT")')
  write(*,'("  for all species and atoms")')
end if
if (wannier) then
  open(50,file='WFBAND.OUT',action='WRITE',form='FORMATTED')
  do ist=1,wf_dim
    do ik=1,nkpt
      write(50,'(2G18.10)') dpp1d(ik),wf_e(ist,1,ik)-efermi
    end do
    write(50,'("     ")')
  end do
  close(50)
endif


! output the vertex location lines
open(50,file='BANDLINES.OUT',action='WRITE',form='FORMATTED')
do iv=1,nvp1d
  write(50,'(2G18.10)') dvp1d(iv),emin
  write(50,'(2G18.10)') dvp1d(iv),emax
  write(50,'("     ")')
end do
close(50)
write(*,'(" vertex location lines written to BANDLINES.OUT")')
write(*,*)

if (task.eq.21) then
  !--- write band-character information
  open(50,file='BANDS.OUT',action='WRITE',form='FORMATTED')
  write(50,*)lmmax,natmtot,nspinor,nstsv,nkpt,nvp1d
  do ik = 1, nkpt
    write(50,*)dpp1d(ik)
    write(50,*)(e(ist,ik),ist=1,nstsv)
    write(50,*)((((bndchr(lm,ias,ispn,ist,ik),lm=1,lmmax), &
               ias=1,natmtot),ispn=1,nspinor),ist=1,nstsv)
  enddo
  close(50)
endif

deallocate(e)
if (task.eq.21) then
  deallocate(bc,bndchr)
endif
if (wannier) then
  deallocate(ufr,uu)
endif

return
end subroutine

subroutine calc_uu(lmax,mtord,ufr,uu)
use modmain
implicit none
integer, intent(in) :: lmax
integer, intent(in) :: mtord
real(8), intent(in) :: ufr(nrmtmax,0:lmax,mtord,natmtot)
real(8), intent(out) :: uu(0:lmax,mtord,mtord,natmtot)

real(8) fr(nrmtmax),gr(nrmtmax),cf(3,nrmtmax)
integer is,ia,ias,l,io1,io2,ir

do is=1,nspecies
  do ia=1,natoms(is)
    ias=idxas(ia,is)
    do l=0,lmax
      do io1=1,mtord
        do io2=1,mtord
          do ir=1,nrmt(is)
            fr(ir)=ufr(ir,l,io1,ias)*ufr(ir,l,io2,ias)*(spr(ir,is)**2)                                                        
          enddo
          call fderiv(-1,nrmt(is),spr(1,is),fr,gr,cf)
          uu(l,io1,io2,ias)=gr(nrmt(is))
        enddo
      enddo
    enddo 
  enddo
enddo

return
end
!EOC
