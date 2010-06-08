subroutine writeme(ikloc,fname,me,wann_c2,pmat)
#ifdef _HDF5_
use modmain
implicit none
integer, intent(in) :: ikloc
character*(*), intent(in) :: fname 
complex(8), intent(in) :: me(ngvecme,nmemax)
complex(8), intent(in) :: wann_c2(nwann,nstsv)
complex(8), intent(in) :: pmat(3,nstsv,nstsv)

character*100 path
integer ik

call idxglob(nkptnr,mpi_dims(1),mpi_x(1)+1,ikloc,ik)

write(path,'("/kpoints/",I8.8)')ik
call write_integer(idxkq(1,ik),1,trim(fname),trim(path),'kq')
call write_integer(nme(ikloc),1,trim(fname),trim(path),'nme')
if (nme(ikloc).gt.0) then
  call write_integer_array(ime(1,1,ikloc),2,(/3,nme(ikloc)/), &
    trim(fname),trim(path),'ime')
  call write_real8(docc(1,ikloc),nme(ikloc), &
    trim(fname),trim(path),'docc')
  call write_real8_array(me,3,(/2,ngvecme,nme(ikloc)/), &
    trim(fname),trim(path),'me')
endif
if (wannier) then
  call write_real8_array(wann_c(1,1,ikloc),3,(/2,nwann,nstsv/), &
    trim(fname),trim(path),'wann_c_k')
  call write_real8_array(wann_c2,3,(/2,nwann,nstsv/), &
    trim(fname),trim(path),'wann_c_kq')
endif   
if (lwannopt) then
  call write_real8_array(pmat,4,(/2,3,nstsv,nstsv/),&
    trim(fname),trim(path),'pmat')
endif
#endif
return
end