#ifndef __LAPW_H__
#define __LAPW_H__

#include <vector>
#include <string>
#include <map>

struct atomic_level 
{
    int n;
    int l;
    int k;
    int occupancy;
};

struct radial_solution_descriptor
{
    int n;
    int l;
    int dme;
    double enu;
    bool auto_enu;
};

class radial_l_channel_descriptor
{
    public:
        radial_l_channel_descriptor()
        {
        }
        
        radial_l_channel_descriptor(int l) : l(l)
        {
        }
    
        int l;
        std::vector<radial_solution_descriptor> rsd;
};

class Species 
{
    public:

        Species() 
        {
        }
    
        Species(const std::string& symbol) : symbol(symbol) 
        {
        };
        
        std::string name;
        std::string symbol;
        int number;
        double mass;
        double rmin;
        double rmax;
        double rmt;
        int nrmt;
  
        std::vector<atomic_level> core;
        std::vector<radial_l_channel_descriptor> lo_descriptors;
        std::vector<radial_l_channel_descriptor> apw_descriptors;
};

class local_orbital_index 
{
    public:
        local_orbital_index(int l, int m, int lm, int ilo) : l(l), m(m), lm(lm), ilo(ilo)
        {
        }
        
        int l;
        int m;
        int lm;
        int ilo;
};

class Atom 
{
    public:
        
        Atom()
        {
        }

        Atom(Species *species) : species(species)
        {
            
        }
        
        double posl[3];
        double posc[3];
        double bfcmt[3];
        int symclass;
        Species *species;
        int local_orbital_offset;
        std::vector<local_orbital_index> idxlo;
};

class Geometry 
{
    public:
    
        std::vector< std::vector<double> > avec;
        double avec_m[9];
        double ainv_m[9];
        std::vector< std::vector<double> > bvec;
        double bvec_m[9];
        double binv_m[9];
        std::vector<Species> species;
        std::map<std::string,Species*> species_by_symbol;
        std::vector<Atom> atoms;
};


#endif // __LAPW_H__
