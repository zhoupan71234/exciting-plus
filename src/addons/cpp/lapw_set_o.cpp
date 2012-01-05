#include "lapw.h"

void lapw_set_o(int ngp,
                int ldo,
                tensor<int,1>& igpig,
                tensor<std::complex<double>,2>& capwalm,
                tensor<double,4>& ovlprad,
                tensor<std::complex<double>,2>& o)
{
    zgemm<gemm_worker>(0 ,2, ngp, ngp, p.wfmt_size_apw, zone, &capwalm(0, 0), ngp, &capwalm(0, 0), ngp, zzero, &o(0, 0), ldo);

    for (unsigned int ias = 0; ias < geometry.atoms.size(); ias++)
    {
        Atom *atom = &geometry.atoms[ias];
        Species *species = atom->species;

        for (unsigned int j2 = 0; j2 < species->size_ci_lo; j2++) // loop over columns (local-orbital block) 
        {
            int l2 = species->ci_lo[j2].l;
            int lm2 = species->ci_lo[j2].lm;
            int order2 = species->ci_lo[j2].order;
            
            // apw-lo block 
            for (unsigned int io1 = 0; io1 < species->apw_descriptors[l2].radial_solution_descriptors.size(); io1++)
                for (int ig = 0; ig < ngp; ig++)
                    o(ig, ngp + atom->offset_lo + j2) += ovlprad(l2, io1, order2, ias) * capwalm(ig, atom->offset_apw + species->ci_by_lmo(lm2, io1)); 

            // lo-lo block
            for (unsigned int j1 = 0; j1 <= j2; j1++)
            {
                int lm1 = species->ci_lo[j1].lm;
                int order1 = species->ci_lo[j1].order;
                if (lm1 == lm2) 
                    o(ngp + atom->offset_lo + j1, ngp + atom->offset_lo + j2) += ovlprad(l2, order1, order2, ias);
            }
        }
    }
    
    int iv[3];
    for (int j2 = 0; j2 < ngp; j2++) // loop over columns
    {
        int ig2 = igpig(j2) - 1;
        for (int j1 = 0; j1 <= j2; j1++) // for each column loop over rows
        {
            for (int k = 0; k < 3; k++) iv[k] = p.ivg(k, igpig(j1) - 1) - p.ivg(k, ig2);
            int ig = p.ivgig(iv[0], iv[1], iv[2]);
            o(j1, j2) += p.cfunig[ig];
        }
    }
}

